with Abacus.Arith;    use Abacus.Arith;
with Abacus.Cholesky;
with Abacus.Matrices; use Abacus.Matrices;
with Abacus.Qp.Cones;

package body Abacus.Qp.Polish
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

   --  The side a constraint at Z with multiplier Y holds in [Lo, Hi].
   function Side_Of (Z, Y, Lo, Hi : Val) return Side
   is (if Lo = Hi
       then At_Lower
       elsif Lo /= No_Lower and then Wide (Z) - Wide (Lo) < -Wide (Y)
       then At_Lower
       elsif Hi /= No_Upper and then Wide (Hi) - Wide (Z) < Wide (Y)
       then At_Upper
       else Free);

   --  The bound a held side names.
   function Bound_Of (S : Side; Lo, Hi : Val) return Val
   is (if S = At_Upper then Hi else Lo);

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

   function Is_Free (Work : Workspace; I : Index) return Boolean
   is (Work.Box_Side (I) = Free)
   with Pre => I <= Work.N;

   function Is_Held_Row (Work : Workspace; R : Index) return Boolean
   is (Work.Row_Side (R) /= Free)
   with Pre => R <= Work.K;

   --  Whether Work's maps name places of Pr.
   function Packed (Pr : Problem; Work : Workspace) return Boolean
   is (Fits_Work (Pr, Work)
       and then Work.Free_Count <= Pr.N
       and then Work.Row_Count <= Pr.K
       and then (for all Q in 1 .. Work.Free_Count => Work.Free_At (Q) <= Pr.N)
       and then (for all P in 1 .. Work.Row_Count => Work.Row_At (P) <= Pr.K));

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

   --  Entry (P, R) of A A' + delta**2 I.
   function Row_Entry (Work : Workspace; P, R : Index) return Wide
   is (Round_Shift (Row_Dot (Work.A, P, R, 1, Work.Free_Count))
       + (if P = R then Delta_Squared else 0))
   with
     Pre =>
       P <= Work.K and then R <= Work.K and then Work.Free_Count <= Work.N;

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
            Store (Row_Entry (Work, P, R), Work.G (P, R), Ok);
         end loop;
      end loop;
      Cholesky.Factor_Leading (Work.G, Work.G_D, Work.Row_Count, 1, Outcome);
      Ok := Ok and then Outcome.Result = Cholesky.Factored;
   end Form_G;

   ---------------------------------------------------------------------
   --  The free variables and the held rows' multipliers.
   ---------------------------------------------------------------------

   --  The packed vectors a solve works with: the held rows' multipliers
   --  (Lam) and gaps, and the step a refinement takes over the free
   --  variables.
   type Packed_Vectors
     (N : Index;
      K : Count)
   is record
      Lam  : Vector (1 .. K);
      Gap  : Vector (1 .. K);
      Step : Vector (1 .. N);
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

   --  -(P x + q + A'lambda) at free variable Q.
   function Stationarity
     (Pr   : Problem;
      Work : Workspace;
      Cand : State;
      C    : Packed_Vectors;
      Q    : Index) return Wide
   is (-(Round_Shift (Row_Vector_Dot (Pr.P, Work.Free_At (Q), Cand.X, 1, Pr.N))
         + Wide (Pr.Q (Work.Free_At (Q)))
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

   --  P x + q.
   procedure Gradient
     (Pr : Problem; Cand : State; Gr : out Vector; Ok : in out Boolean)
   with
     Pre => Fits_State (Pr, Cand) and then Gr'First = 1 and then Gr'Last = Pr.N
   is
   begin
      Gr := [others => 0];
      for I in 1 .. Pr.N loop
         Store
           (Round_Shift (Row_Vector_Dot (Pr.P, I, Cand.X, 1, Pr.N))
            + Wide (Pr.Q (I)),
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

   procedure Solve_Held
     (Pr   : Problem;
      Work : in out Workspace;
      From : State;
      Cand : out State;
      Ok   : out Boolean)
   is
      Gr : Vector (1 .. Pr.N);
      C  : Packed_Vectors (Pr.N, Pr.K) :=
        (Pr.N, Pr.K, [others => 0], [others => 0], [others => 0]);
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
      Gradient (Pr, Cand, Gr, Ok);
      for K in 1 .. Y_Refinements loop
         exit when not Ok;
         Refine_Y (Pr, Work, Gr, C, Ok);
      end loop;
      Unpack (Work, C, Cand);
      Settle (Pr, Work, Gr, Cand, Ok);
   end Solve_Held;

   ---------------------------------------------------------------------
   --  Corrections.
   ---------------------------------------------------------------------

   --  A constraint picked for correction: how far it is wrong, whether it
   --  is a row, which, and the side it is to take.
   type Pick is record
      Size   : Wide := 0;
      In_Row : Boolean := False;
      Place  : Index := Index'First;
      To     : Side := Free;
   end record;

   --  How hard a held side's multiplier Y pushes the wrong way: a lower
   --  bound's must not be positive, an upper's not negative.  An
   --  equality holds either way.
   function Wrong_Push (S : Side; Y, Lo, Hi : Val) return Wide
   is (if Lo = Hi
       then 0
       elsif S = At_Lower and then Y > 0
       then Wide (Y)
       elsif S = At_Upper and then Y < 0
       then -Wide (Y)
       else 0);

   --  The side a value A past [Lo, Hi] passes.
   function Passed_Side (A : Wide; Hi : Val) return Side
   is (if A > Wide (Hi) then At_Upper else At_Lower);

   --  P with the candidate (Size, In_Row, Place, To) when it is larger.
   procedure Keep_Larger (P : in out Pick; Candidate : Pick) is
   begin
      if Candidate.Size > P.Size then
         P := Candidate;
      end if;
   end Keep_Larger;

   --  The held bound whose multiplier pushes hardest the wrong way.
   function Worst_Push
     (Pr : Problem; Cand : State; Work : Workspace) return Pick
   with Pre => Fits_Work (Pr, Work) and then Fits_State (Pr, Cand)
   is
      P : Pick;
   begin
      for I in 1 .. Pr.N loop
         Keep_Larger
           (P,
            (Wrong_Push (Work.Box_Side (I), Cand.Y (I), Pr.Lo (I), Pr.Hi (I)),
             False,
             I,
             Free));
      end loop;
      for R in 1 .. Pr.K loop
         Keep_Larger
           (P,
            (Wrong_Push
               (Work.Row_Side (R),
                Cand.Y_Row (R),
                Pr.Row_Lo (R),
                Pr.Row_Hi (R)),
             True,
             R,
             Free));
      end loop;
      return P;
   end Worst_Push;

   --  The free constraint Cand lies furthest outside.
   function Worst_Excess
     (Pr : Problem; Cand : State; Work : Workspace) return Pick
   with Pre => Fits_Work (Pr, Work) and then Fits_State (Pr, Cand)
   is
      P : Pick;
   begin
      for I in 1 .. Pr.N loop
         if Is_Free (Work, I) then
            Keep_Larger
              (P,
               (Certificate.Outside (Wide (Cand.X (I)), Pr.Lo (I), Pr.Hi (I)),
                False,
                I,
                Passed_Side (Wide (Cand.X (I)), Pr.Hi (I))));
         end if;
      end loop;
      for R in 1 .. Pr.K loop
         if not Is_Held_Row (Work, R) and then not Cones.In_Cone (Pr, R) then
            Keep_Larger
              (P,
               (Certificate.Outside
                  (Certificate.Row_Of (Pr, R, Cand.X),
                   Pr.Row_Lo (R),
                   Pr.Row_Hi (R)),
                True,
                R,
                Passed_Side
                  (Certificate.Row_Of (Pr, R, Cand.X), Pr.Row_Hi (R))));
         end if;
      end loop;
      return P;
   end Worst_Excess;

   procedure Correct
     (Pr      : Problem;
      Cand    : State;
      Work    : in out Workspace;
      Changed : out Boolean)
   is
      P : Pick := Worst_Push (Pr, Cand, Work);
   begin
      if P.Size = 0 then
         P := Worst_Excess (Pr, Cand, Work);
      end if;
      Changed := P.Size > 0;
      if Changed and then P.In_Row and then P.Place <= Pr.K then
         Work.Row_Side (P.Place) := P.To;
      elsif Changed and then P.Place <= Pr.N then
         Work.Box_Side (P.Place) := P.To;
      end if;
   end Correct;

   procedure Run
     (Pr     : Problem;
      S      : Settings;
      Work   : in out Workspace;
      St     : in out State;
      Passed : out Boolean)
   is
      Cand    : State (Pr.N, Pr.K);
      Ok      : Boolean;
      Changed : Boolean;
   begin
      Passed := False;
      if Cones.Has_Cone (Pr) then
         return;
      end if;
      Read_Held (Pr, St, Work);
      for Round in 0 .. Max_Corrections loop
         Solve_Held (Pr, Work, St, Cand, Ok);
         exit when not Ok;
         if Certificate.Certified (Pr, Cand, S.Tol) then
            St := Cand;
            Passed := True;
            exit;
         end if;
         Correct (Pr, Cand, Work, Changed);
         exit when not Changed;
         pragma Loop_Invariant (not Passed and then St = St'Loop_Entry);
      end loop;
   end Run;

end Abacus.Qp.Polish;
