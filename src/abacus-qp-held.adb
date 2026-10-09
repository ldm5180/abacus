with Abacus.Arith;    use Abacus.Arith;
with Abacus.Cholesky;
with Abacus.Matrices; use Abacus.Matrices;
with Abacus.Qp.Certificate;
with Abacus.Qp.Cones;

package body Abacus.Qp.Held
  with SPARK_Mode
is

   use type Cholesky.Factor_Result;
   use type Cholesky.Solve_Result;

   --  The regularization, delta = 2**-Delta_Shift.  The refinement
   --  contracts by about delta over the held rows' least singular value
   --  squared, so delta is small; the system it factors is scaled by
   --  delta, A'A + delta P + delta**2 I, so its entries stay values.
   Delta_Shift : constant := 12;

   --  delta**2, in units.
   Delta_Squared : constant := 2**(Frac - 2 * Delta_Shift);

   --  How many times x and the rows' multipliers are refined.
   X_Refinements : constant := 10;
   Y_Refinements : constant := 6;

   procedure Read_Held (Pr : Problem; St : State; Work : in out Workspace) is
   begin
      for I in 1 .. Pr.N loop
         Work.Box_Side (I) :=
           Side_Of (St.Z (I), St.Y (I), Pr.Lo (I), Pr.Hi (I));
      end loop;
      for R in 1 .. Pr.K loop
         Work.Row_Side (R) :=
           (if Cones.In_Cone (Pr, R)
            then Free
            else
              Side_Of
                (St.Z_Row (R), St.Y_Row (R), Pr.Row_Lo (R), Pr.Row_Hi (R)));
      end loop;
   end Read_Held;

   ---------------------------------------------------------------------
   --  The systems the polish solves with, packed: free variable Q is
   --  Free_At (Q), held row P is Row_At (P).
   ---------------------------------------------------------------------

   --  The free variables in order, then the held rows.
   procedure Pack (Pr : Problem; Work : in out Workspace)
   with Pre => Fits_Work (Pr, Work), Post => Packed (Pr, Work)
   is
   begin
      Work.Free_Count := 0;
      for I in 1 .. Pr.N loop
         if Is_Free (Work, I) then
            Work.Free_Count := Work.Free_Count + 1;
            Work.Free_At (Work.Free_Count) := I;
         end if;
         pragma Loop_Invariant (Work.Free_Count <= I);
         pragma
           Loop_Invariant
             (for all Q in 1 .. Work.Free_Count => Work.Free_At (Q) <= I);
      end loop;
      Work.Row_Count := 0;
      for R in 1 .. Pr.K loop
         if Is_Held_Row (Work, R) then
            Work.Row_Count := Work.Row_Count + 1;
            Work.Row_At (Work.Row_Count) := R;
         end if;
         pragma Loop_Invariant (Work.Free_Count <= Pr.N);
         pragma
           Loop_Invariant
             (for all Q in 1 .. Work.Free_Count => Work.Free_At (Q) <= Pr.N);
         pragma Loop_Invariant (Work.Row_Count <= R);
         pragma
           Loop_Invariant
             (for all P in 1 .. Work.Row_Count => Work.Row_At (P) <= R);
      end loop;
   end Pack;

   --  A (P, Q) = E (Row_At (P), Free_At (Q)) over the free columns; the
   --  rows past the held ones zero.
   procedure Form_A (Pr : Problem; Work : in out Workspace)
   with Pre => Packed (Pr, Work), Post => Packed (Pr, Work)
   is
   begin
      for P in 1 .. Pr.K loop
         for Q in 1 .. Work.Free_Count loop
            Work.A (P, Q) :=
              (if P <= Work.Row_Count
               then Pr.E (Work.Row_At (P), Work.Free_At (Q))
               else 0);
         end loop;
      end loop;
   end Form_A;

   --  Entry (I, J) of A'A + delta P + delta**2 I.
   function Free_Entry
     (Pr : Problem; Work : Workspace; I, J : Index) return Wide
   is (Round_Shift (Column_Dot (Work.A, I, J))
       + Scaled (Pr.P (Work.Free_At (I), Work.Free_At (J)), -Delta_Shift)
       + (if I = J then Delta_Squared else 0))
   with
     Pre =>
       Packed (Pr, Work)
       and then I <= Work.Free_Count
       and then J <= Work.Free_Count;

   --  Entry (P, R) of A A' + Ridge I.
   function Row_Entry
     (Work : Workspace; P, R : Index; Ridge : Wide) return Wide
   is (Round_Shift (Row_Dot (Work.A, P, R, 1, Work.Free_Count))
       + (if P = R then Ridge else 0))
   with
     Pre =>
       P <= Work.K
       and then R <= Work.K
       and then Work.Free_Count <= Work.N
       and then Ridge in 0 .. Delta_Squared;

   --  A'A + delta P + delta**2 I, factored into S's leading block.
   procedure Form_S
     (Pr : Problem; Work : in out Workspace; Ok : in out Boolean)
   with Pre => Packed (Pr, Work), Post => Packed (Pr, Work)
   is
      Outcome : Cholesky.Factor_Outcome;
   begin
      for I in 1 .. Work.Free_Count loop
         for J in 1 .. I loop
            Store (Free_Entry (Pr, Work, I, J), Work.S (I, J), Ok);
         end loop;
      end loop;
      Cholesky.Factor_Leading (Work.S, Work.S_D, Work.Free_Count, 1, Outcome);
      Ok := Ok and then Outcome.Result = Cholesky.Factored;
   end Form_S;

   --  A A' + delta**2 I, factored into G's leading block.
   procedure Form_G
     (Pr : Problem; Work : in out Workspace; Ok : in out Boolean)
   with Pre => Packed (Pr, Work), Post => Packed (Pr, Work)
   is
      Outcome : Cholesky.Factor_Outcome;
   begin
      for P in 1 .. Work.Row_Count loop
         for R in 1 .. P loop
            Store (Row_Entry (Work, P, R, Delta_Squared), Work.G (P, R), Ok);
         end loop;
      end loop;
      Cholesky.Factor_Leading (Work.G, Work.G_D, Work.Row_Count, 1, Outcome);
      Ok := Ok and then Outcome.Result = Cholesky.Factored;
   end Form_G;

   ---------------------------------------------------------------------
   --  The free variables and the held rows' multipliers.
   ---------------------------------------------------------------------

   --  The packed vectors a solve works with: the held rows' multipliers
   --  (Lam) and gaps, the step a refinement takes over the free
   --  variables, and the cost's linear term the solve is for.
   type Packed_Vectors
     (N : Index;
      K : Count)
   is record
      Lam  : Vector (1 .. K);
      Gap  : Vector (1 .. K);
      Step : Vector (1 .. N);
      Cost : Vector (1 .. N);
   end record;

   function Fits_Vectors (Pr : Problem; C : Packed_Vectors) return Boolean
   is (C.N = Pr.N and then C.K = Pr.K);

   --  From's x with each held variable at its bound, and From's
   --  multipliers on the held rows, packed.
   procedure Start
     (Pr   : Problem;
      Work : Workspace;
      From : State;
      C    : in out Packed_Vectors;
      Cand : out State)
   with
     Pre =>
       Packed (Pr, Work)
       and then Fits_State (Pr, From)
       and then Fits_Vectors (Pr, C)
       and then Cand.N = Pr.N
       and then Cand.K = Pr.K
   is
   begin
      Cand := Cold (Pr.N, Pr.K);
      Cand.Iterations := From.Iterations;
      for I in 1 .. Pr.N loop
         Cand.X (I) :=
           (if Is_Free (Work, I)
            then From.X (I)
            else Bound_Of (Work.Box_Side (I), Pr.Lo (I), Pr.Hi (I)));
      end loop;
      C.Lam := [others => 0];
      for P in 1 .. Work.Row_Count loop
         C.Lam (P) := From.Y_Row (Work.Row_At (P));
      end loop;
   end Start;

   --  -(P x + c + A'lambda) at free variable Q, c the solve's cost.
   function Stationarity
     (Pr   : Problem;
      Work : Workspace;
      Cand : State;
      C    : Packed_Vectors;
      Q    : Index) return Wide
   is (-(Round_Shift (Row_Vector_Dot (Pr.P, Work.Free_At (Q), Cand.X, 1, Pr.N))
         + Wide (C.Cost (Work.Free_At (Q)))
         + Round_Shift (Column_Vector_Dot (Work.A, Q, C.Lam))))
   with
     Pre =>
       Packed (Pr, Work)
       and then Fits_State (Pr, Cand)
       and then Fits_Vectors (Pr, C)
       and then Q <= Work.Free_Count;

   --  The bound row R is held at, less E x.
   function Row_Gap_Of
     (Pr : Problem; Work : Workspace; Cand : State; R : Index) return Wide
   is (Wide (Bound_Of (Work.Row_Side (R), Pr.Row_Lo (R), Pr.Row_Hi (R)))
       - Certificate.Row_Of (Pr, R, Cand.X))
   with
     Pre =>
       Fits_Work (Pr, Work) and then Fits_State (Pr, Cand) and then R <= Pr.K;

   --  The step's scale: a fine step is formed and solved 2**Delta_Shift
   --  times finer than the grid.
   Fine_Scale : constant := 2**Delta_Shift;

   --  The largest gap a fine step is taken from: the multipliers' change
   --  is about the gap times Fine_Scale, and a larger one is the first
   --  steps' work, which the grid's scale does well enough.
   Fine_Gap : constant := 2**Frac;

   --  The held rows' gaps.
   procedure Gaps
     (Pr   : Problem;
      Work : Workspace;
      Cand : State;
      C    : in out Packed_Vectors;
      Ok   : in out Boolean)
   with
     Pre =>
       Packed (Pr, Work)
       and then Fits_State (Pr, Cand)
       and then Fits_Vectors (Pr, C)
   is
   begin
      C.Gap := [others => 0];
      for P in 1 .. Work.Row_Count loop
         Store (Row_Gap_Of (Pr, Work, Cand, Work.Row_At (P)), C.Gap (P), Ok);
      end loop;
   end Gaps;

   --  Whether every held row's gap is within Fine_Gap.
   function Small_Gaps (Work : Workspace; C : Packed_Vectors) return Boolean
   is (for all P in 1 .. Work.Row_Count => C.Gap (P) in -Fine_Gap .. Fine_Gap)
   with Pre => Work.Row_Count <= C.K;

   --  The right side of the regularized step over the free variables,
   --  delta (-(P x + q + A'lambda)) + A' gap, at the grid's scale.
   procedure Coarse_Side
     (Pr   : Problem;
      Work : Workspace;
      Cand : State;
      C    : in out Packed_Vectors;
      Ok   : in out Boolean)
   with
     Pre =>
       Packed (Pr, Work)
       and then Fits_State (Pr, Cand)
       and then Fits_Vectors (Pr, C)
   is
      Pull : Val := 0;
   begin
      C.Step := [others => 0];
      for Q in 1 .. Work.Free_Count loop
         Store (Stationarity (Pr, Work, Cand, C, Q), Pull, Ok);
         Store
           (Scaled (Pull, -Delta_Shift)
            + Round_Shift (Column_Vector_Dot (Work.A, Q, C.Gap)),
            C.Step (Q),
            Ok);
      end loop;
   end Coarse_Side;

   --  The same right side Fine_Scale times finer, rounded once from the
   --  exact sums: -(P x + q + A'lambda) + A' gap / delta.  Its rounding
   --  is then a unit of the fine scale, where the coarse side's is a unit
   --  of the grid, which the null space of the held rows, solved through
   --  delta P, multiplies by 1 / delta.
   procedure Fine_Side
     (Pr   : Problem;
      Work : Workspace;
      Cand : State;
      C    : in out Packed_Vectors;
      Ok   : in out Boolean)
   with
     Pre =>
       Packed (Pr, Work)
       and then Fits_State (Pr, Cand)
       and then Fits_Vectors (Pr, C)
   is
      Pull : Val := 0;
   begin
      C.Step := [others => 0];
      for Q in 1 .. Work.Free_Count loop
         Store (Stationarity (Pr, Work, Cand, C, Q), Pull, Ok);
         Store
           (Wide (Pull)
            + Div_Round
                (Column_Vector_Dot (Work.A, Q, C.Gap), One / Fine_Scale),
            C.Step (Q),
            Ok);
      end loop;
   end Fine_Side;

   --  Whether Work's free variables are places of a state of its size.
   function Free_Packed (Work : Workspace) return Boolean
   is (Work.Free_Count <= Work.N
       and then (for all Q in 1 .. Work.Free_Count =>
                   Work.Free_At (Q) <= Work.N));

   --  The free variables moved by the step, brought from 2**Finer times
   --  the grid's scale back to it.
   procedure Move_Free
     (Work  : Workspace;
      C     : Packed_Vectors;
      Finer : Natural;
      Cand  : in out State;
      Ok    : in out Boolean)
   with
     Pre =>
       Free_Packed (Work)
       and then Cand.N = Work.N
       and then C.N = Work.N
       and then Finer <= Delta_Shift
   is
   begin
      for Q in 1 .. Work.Free_Count loop
         Store
           (Wide (Cand.X (Work.Free_At (Q))) + Scaled (C.Step (Q), -Finer),
            Cand.X (Work.Free_At (Q)),
            Ok);
      end loop;
   end Move_Free;

   --  A held row's A step - gap, at the scale of the step.
   function Row_Change
     (Work : Workspace; C : Packed_Vectors; P : Index; Gap : Wide) return Wide
   is (Round_Shift (Row_Vector_Dot (Work.A, P, C.Step, 1, Work.Free_Count))
       - Gap)
   with
     Pre =>
       P <= Work.K
       and then Work.Free_Count <= Work.N
       and then C.N = Work.N
       and then Gap in -Fine_Scale * Val_Bound .. Fine_Scale * Val_Bound;

   --  The coarse step taken: the free variables move by it, and each held
   --  row's multiplier by (A step - gap) / delta.
   procedure Take_Step
     (Pr   : Problem;
      Work : Workspace;
      C    : in out Packed_Vectors;
      Cand : in out State;
      Ok   : in out Boolean)
   with
     Pre =>
       Packed (Pr, Work)
       and then Fits_State (Pr, Cand)
       and then Fits_Vectors (Pr, C)
   is
      Change : Val := 0;
   begin
      Move_Free (Work, C, 0, Cand, Ok);
      for P in 1 .. Work.Row_Count loop
         Store (Row_Change (Work, C, P, Wide (C.Gap (P))), Change, Ok);
         Store
           (Wide (C.Lam (P)) + Scaled (Change, Delta_Shift), C.Lam (P), Ok);
      end loop;
   end Take_Step;

   --  The fine step taken: the free variables move by it brought back to
   --  the grid, and each held row's multiplier by A step - gap / delta,
   --  both already at the multipliers' scale.
   procedure Take_Fine_Step
     (Pr   : Problem;
      Work : Workspace;
      C    : in out Packed_Vectors;
      Cand : in out State;
      Ok   : in out Boolean)
   with
     Pre =>
       Packed (Pr, Work)
       and then Fits_State (Pr, Cand)
       and then Fits_Vectors (Pr, C)
   is
   begin
      Move_Free (Work, C, Delta_Shift, Cand, Ok);
      for P in 1 .. Work.Row_Count loop
         Store
           (Wide (C.Lam (P))
            + Row_Change (Work, C, P, Wide (C.Gap (P)) * Fine_Scale),
            C.Lam (P),
            Ok);
      end loop;
   end Take_Fine_Step;

   --  One refinement of x and the held rows' multipliers against the
   --  exact system, solved with the regularized one: at the fine scale
   --  when the gaps allow and the step stays in range, else at the grid's.
   procedure Refine_X
     (Pr   : Problem;
      Work : Workspace;
      C    : in out Packed_Vectors;
      Cand : in out State;
      Ok   : in out Boolean)
   with
     Pre =>
       Packed (Pr, Work)
       and then Fits_State (Pr, Cand)
       and then Fits_Vectors (Pr, C)
   is
      Solved : Cholesky.Solve_Result;
      Fine   : Boolean;
   begin
      Gaps (Pr, Work, Cand, C, Ok);
      Fine := Small_Gaps (Work, C);
      if Fine then
         Fine_Side (Pr, Work, Cand, C, Fine);
      end if;
      if Fine then
         Cholesky.Solve_Leading
           (Work.S, Work.S_D, C.Step, Work.Free_Count, Solved);
         Fine := Solved = Cholesky.Solved;
      end if;
      if Fine then
         Take_Fine_Step (Pr, Work, C, Cand, Ok);
         return;
      end if;
      Coarse_Side (Pr, Work, Cand, C, Ok);
      Cholesky.Solve_Leading
        (Work.S, Work.S_D, C.Step, Work.Free_Count, Solved);
      Ok := Ok and then Solved = Cholesky.Solved;
      if Ok then
         Take_Step (Pr, Work, C, Cand, Ok);
      end if;
   end Refine_X;

   ---------------------------------------------------------------------
   --  The multipliers.
   ---------------------------------------------------------------------

   --  P x + c, c the solve's cost.
   procedure Gradient
     (Pr   : Problem;
      C    : Packed_Vectors;
      Cand : State;
      Gr   : out Vector;
      Ok   : in out Boolean)
   with
     Pre =>
       Fits_State (Pr, Cand)
       and then Fits_Vectors (Pr, C)
       and then Gr'First = 1
       and then Gr'Last = Pr.N
   is
   begin
      Gr := [others => 0];
      for I in 1 .. Pr.N loop
         Store
           (Round_Shift (Row_Vector_Dot (Pr.P, I, Cand.X, 1, Pr.N))
            + Wide (C.Cost (I)),
            Gr (I),
            Ok);
      end loop;
   end Gradient;

   --  One least-squares refinement of the held rows' multipliers: the
   --  free variables' residual -(P x + q + A'lambda), brought through A
   --  and solved with A A'.
   procedure Refine_Y
     (Pr   : Problem;
      Work : Workspace;
      Gr   : Vector;
      C    : in out Packed_Vectors;
      Ok   : in out Boolean)
   with
     Pre =>
       Packed (Pr, Work)
       and then Fits_Vectors (Pr, C)
       and then Gr'First = 1
       and then Gr'Last = Pr.N
   is
      Res    : Vector (1 .. Pr.N) := [others => 0];
      Rhs    : Vector (1 .. Pr.K) := [others => 0];
      Solved : Cholesky.Solve_Result;
   begin
      for Q in 1 .. Work.Free_Count loop
         Store
           (-(Wide (Gr (Work.Free_At (Q)))
              + Round_Shift (Column_Vector_Dot (Work.A, Q, C.Lam))),
            Res (Q),
            Ok);
      end loop;
      for P in 1 .. Work.Row_Count loop
         Store
           (Round_Shift (Row_Vector_Dot (Work.A, P, Res, 1, Work.Free_Count)),
            Rhs (P),
            Ok);
      end loop;
      Cholesky.Solve_Leading (Work.G, Work.G_D, Rhs, Work.Row_Count, Solved);
      Ok := Ok and then Solved = Cholesky.Solved;
      for P in 1 .. Work.Row_Count loop
         exit when not Ok;
         Store (Wide (C.Lam (P)) + Wide (Rhs (P)), C.Lam (P), Ok);
      end loop;
   end Refine_Y;

   --  The held rows' multipliers unpacked into Cand's, zero elsewhere.
   procedure Unpack (Work : Workspace; C : Packed_Vectors; Cand : in out State)
   with
     Pre =>
       Work.Row_Count <= Work.K
       and then (for all P in 1 .. Work.Row_Count => Work.Row_At (P) <= Work.K)
       and then C.K = Work.K
       and then Cand.K = Work.K
   is
   begin
      Cand.Y_Row := [others => 0];
      for P in 1 .. Work.Row_Count loop
         Cand.Y_Row (Work.Row_At (P)) := C.Lam (P);
      end loop;
   end Unpack;

   --  The held variables' multipliers, -(P x + q + E'y_row), and the
   --  projections z and z_row of x and E x.
   procedure Settle
     (Pr   : Problem;
      Work : Workspace;
      Gr   : Vector;
      Cand : in out State;
      Ok   : in out Boolean)
   with
     Pre =>
       Fits_Work (Pr, Work)
       and then Fits_State (Pr, Cand)
       and then Gr'First = 1
       and then Gr'Last = Pr.N
   is
   begin
      for I in 1 .. Pr.N loop
         Cand.Y (I) := 0;
         if not Is_Free (Work, I) then
            Store
              (-(Wide (Gr (I))
                 + Round_Shift (Column_Vector_Dot (Pr.E, I, Cand.Y_Row))),
               Cand.Y (I),
               Ok);
         end if;
         Cand.Z (I) :=
           Clamp
             (Wide (Cand.X (I)), Pr.Lo (I), Val'Max (Pr.Lo (I), Pr.Hi (I)));
      end loop;
      for R in 1 .. Pr.K loop
         Cand.Z_Row (R) :=
           Clamp
             (Certificate.Row_Of (Pr, R, Cand.X),
              Pr.Row_Lo (R),
              Val'Max (Pr.Row_Lo (R), Pr.Row_Hi (R)));
      end loop;
   end Settle;

   procedure Solve
     (Pr   : Problem;
      Cost : Vector;
      Work : in out Workspace;
      Cand : in out State;
      Ok   : out Boolean)
   is
      From : constant State := Cand;
      Gr   : Vector (1 .. Pr.N);
      C    : Packed_Vectors (Pr.N, Pr.K) :=
        (Pr.N, Pr.K, [others => 0], [others => 0], [others => 0], Cost);
   begin
      Ok := True;
      Pack (Pr, Work);
      Form_A (Pr, Work);
      Form_S (Pr, Work, Ok);
      Start (Pr, Work, From, C, Cand);
      for K in 1 .. X_Refinements loop
         exit when not Ok;
         Refine_X (Pr, Work, C, Cand, Ok);
      end loop;
      Form_G (Pr, Work, Ok);
      Gradient (Pr, C, Cand, Gr, Ok);
      for K in 1 .. Y_Refinements loop
         exit when not Ok;
         Refine_Y (Pr, Work, Gr, C, Ok);
      end loop;
      Unpack (Work, C, Cand);
      Settle (Pr, Work, Gr, Cand, Ok);
   end Solve;

   ---------------------------------------------------------------------
   --  The square system and its dependences.
   ---------------------------------------------------------------------

   --  How many times a square solve is refined.
   Square_Refinements : constant := 4;

   --  One refinement of Z toward A Z = V: the rows' residual solved with
   --  A A' and brought back through A'.
   procedure Refine_Direction
     (Pr   : Problem;
      Work : Workspace;
      V    : Vector;
      Z    : in out Vector;
      Ok   : in out Boolean)
   with
     Pre =>
       Packed (Pr, Work)
       and then V'First = 1
       and then V'Last = Pr.K
       and then Z'First = 1
       and then Z'Last = Pr.N
   is
      Res    : Vector (1 .. Pr.K) := [others => 0];
      Solved : Cholesky.Solve_Result;
   begin
      for P in 1 .. Work.Row_Count loop
         Store
           (Wide (V (P))
            - Round_Shift (Row_Vector_Dot (Work.A, P, Z, 1, Work.Free_Count)),
            Res (P),
            Ok);
      end loop;
      Cholesky.Solve_Leading (Work.G, Work.G_D, Res, Work.Row_Count, Solved);
      Ok := Ok and then Solved = Cholesky.Solved;
      for Q in 1 .. Work.Free_Count loop
         exit when not Ok;
         Store
           (Wide (Z (Q)) + Round_Shift (Column_Vector_Dot (Work.A, Q, Res)),
            Z (Q),
            Ok);
      end loop;
   end Refine_Direction;

   procedure Direction
     (Pr   : Problem;
      Work : Workspace;
      V    : Vector;
      Z    : out Vector;
      Ok   : out Boolean) is
   begin
      Z := [others => 0];
      Ok := True;
      for K in 1 .. Square_Refinements loop
         exit when not Ok;
         Refine_Direction (Pr, Work, V, Z, Ok);
      end loop;
   end Direction;

   --  One refinement of W toward A'W = C: the columns' residual brought
   --  through A and solved with A A'.
   procedure Refine_Prices
     (Pr   : Problem;
      Work : Workspace;
      C    : Vector;
      W    : in out Vector;
      Ok   : in out Boolean)
   with
     Pre =>
       Packed (Pr, Work)
       and then C'First = 1
       and then C'Last = Pr.N
       and then W'First = 1
       and then W'Last = Pr.K
   is
      Res    : Vector (1 .. Pr.N) := [others => 0];
      Rhs    : Vector (1 .. Pr.K) := [others => 0];
      Solved : Cholesky.Solve_Result;
   begin
      for Q in 1 .. Work.Free_Count loop
         Store
           (Wide (C (Q)) - Round_Shift (Column_Vector_Dot (Work.A, Q, W)),
            Res (Q),
            Ok);
      end loop;
      for P in 1 .. Work.Row_Count loop
         Store
           (Round_Shift (Row_Vector_Dot (Work.A, P, Res, 1, Work.Free_Count)),
            Rhs (P),
            Ok);
      end loop;
      Cholesky.Solve_Leading (Work.G, Work.G_D, Rhs, Work.Row_Count, Solved);
      Ok := Ok and then Solved = Cholesky.Solved;
      for P in 1 .. Work.Row_Count loop
         exit when not Ok;
         Store (Wide (W (P)) + Wide (Rhs (P)), W (P), Ok);
      end loop;
   end Refine_Prices;

   procedure Prices
     (Pr   : Problem;
      Work : Workspace;
      C    : Vector;
      W    : out Vector;
      Ok   : out Boolean) is
   begin
      W := [others => 0];
      Ok := True;
      for K in 1 .. Square_Refinements loop
         exit when not Ok;
         Refine_Prices (Pr, Work, C, W, Ok);
      end loop;
   end Prices;

   --  A pivot under it marks a dependence: about 2**-32 of a value left
   --  of a row's or a column's own square once the ones before it are
   --  taken out.
   Dependence_Floor : constant := 2**(Frac - 16);

   --  A A', unregularized, factored into G's leading block with the floor;
   --  the column it refuses at, zero when it factors.
   procedure Row_Dependence
     (Pr     : Problem;
      Work   : in out Workspace;
      At_Row : out Count;
      Ok     : out Boolean)
   with Pre => Packed (Pr, Work), Post => Packed (Pr, Work)
   is
      Outcome : Cholesky.Factor_Outcome;
   begin
      Ok := True;
      for P in 1 .. Work.Row_Count loop
         for R in 1 .. P loop
            Store (Row_Entry (Work, P, R, 0), Work.G (P, R), Ok);
         end loop;
      end loop;
      Cholesky.Factor_Leading
        (Work.G, Work.G_D, Work.Row_Count, Dependence_Floor, Outcome);
      Ok := Ok and then Outcome.Result /= Cholesky.Out_Of_Range;
      At_Row :=
        (if Outcome.Result = Cholesky.Not_Positive_Definite
         then Outcome.Column
         else 0);
   end Row_Dependence;

   --  A'A, unregularized, factored into S's leading block likewise.
   procedure Column_Dependence
     (Pr        : Problem;
      Work      : in out Workspace;
      At_Column : out Count;
      Ok        : out Boolean)
   with Pre => Packed (Pr, Work), Post => Packed (Pr, Work)
   is
      Outcome : Cholesky.Factor_Outcome;
   begin
      Ok := True;
      for I in 1 .. Work.Free_Count loop
         for J in 1 .. I loop
            Store (Round_Shift (Column_Dot (Work.A, I, J)), Work.S (I, J), Ok);
         end loop;
      end loop;
      Cholesky.Factor_Leading
        (Work.S, Work.S_D, Work.Free_Count, Dependence_Floor, Outcome);
      Ok := Ok and then Outcome.Result /= Cholesky.Out_Of_Range;
      At_Column :=
        (if Outcome.Result = Cholesky.Not_Positive_Definite
         then Outcome.Column
         else 0);
   end Column_Dependence;

   procedure Find_Dependence
     (Pr    : Problem;
      Work  : in out Workspace;
      Found : out Dependence;
      Ok    : out Boolean) is
   begin
      Found := (0, 0);
      Pack (Pr, Work);
      Form_A (Pr, Work);
      Row_Dependence (Pr, Work, Found.Row, Ok);
      if Ok and then Found.Row = 0 then
         Column_Dependence (Pr, Work, Found.Column, Ok);
      end if;
   end Find_Dependence;

end Abacus.Qp.Held;
