with Abacus.Arith;    use Abacus.Arith;
with Abacus.Cholesky;
with Abacus.Matrices; use Abacus.Matrices;

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
           Side_Of (St.Z_Row (R), St.Y_Row (R), Pr.Row_Lo (R), Pr.Row_Hi (R));
      end loop;
   end Read_Held;

   ---------------------------------------------------------------------
   --  The systems the polish solves with.
   ---------------------------------------------------------------------

   function Is_Free (Work : Workspace; I : Index) return Boolean
   is (Work.Box_Side (I) = Free)
   with Pre => I <= Work.N;

   function Is_Held_Row (Work : Workspace; R : Index) return Boolean
   is (Work.Row_Side (R) /= Free)
   with Pre => R <= Work.K;

   --  A: E's held rows over the free columns, zero elsewhere.
   procedure Form_A (Pr : Problem; Work : in out Workspace)
   with Pre => Fits_Work (Pr, Work)
   is
   begin
      for R in 1 .. Pr.K loop
         for J in 1 .. Pr.N loop
            Work.A (R, J) :=
              (if Is_Held_Row (Work, R) and then Is_Free (Work, J)
               then Pr.E (R, J)
               else 0);
         end loop;
      end loop;
   end Form_A;

   --  Entry (I, J) of A'A + delta P + delta**2 I.
   function Free_Entry
     (Pr : Problem; Work : Workspace; I, J : Index) return Wide
   is (Round_Shift (Column_Dot (Work.A, I, J))
       + Scaled (Pr.P (I, J), -Delta_Shift)
       + (if I = J then Delta_Squared else 0))
   with Pre => Fits_Work (Pr, Work) and then I <= Pr.N and then J <= Pr.N;

   --  Entry (R, Q) of A A' + delta**2 I.
   function Row_Entry (Work : Workspace; R, Q : Index) return Wide
   is (Round_Shift (Row_Dot (Work.A, R, Q, 1, Work.N))
       + (if R = Q then Delta_Squared else 0))
   with Pre => R <= Work.K and then Q <= Work.K;

   --  The identity's entry (I, J).
   function Identity (I, J : Index) return Val
   is (if I = J then One else 0);

   --  A'A + delta P + delta**2 I over the free variables, the identity
   --  over the held ones, factored into S.
   procedure Form_S
     (Pr : Problem; Work : in out Workspace; Ok : in out Boolean)
   with Pre => Fits_Work (Pr, Work)
   is
      Outcome : Cholesky.Factor_Outcome;
   begin
      for I in 1 .. Pr.N loop
         for J in 1 .. I loop
            if Is_Free (Work, I) and then Is_Free (Work, J) then
               Store (Free_Entry (Pr, Work, I, J), Work.S (I, J), Ok);
            else
               Work.S (I, J) := Identity (I, J);
            end if;
         end loop;
      end loop;
      Cholesky.Factor (Work.S, Work.S_D, 1, Outcome);
      Ok := Ok and then Outcome.Result = Cholesky.Factored;
   end Form_S;

   --  A A' + delta**2 I over the held rows, the identity over the free
   --  ones, factored into G.
   procedure Form_G
     (Pr : Problem; Work : in out Workspace; Ok : in out Boolean)
   with Pre => Fits_Work (Pr, Work)
   is
      Outcome : Cholesky.Factor_Outcome;
   begin
      for R in 1 .. Pr.K loop
         for Q in 1 .. R loop
            if Is_Held_Row (Work, R) and then Is_Held_Row (Work, Q) then
               Store (Row_Entry (Work, R, Q), Work.G (R, Q), Ok);
            else
               Work.G (R, Q) := Identity (R, Q);
            end if;
         end loop;
      end loop;
      Cholesky.Factor (Work.G, Work.G_D, 1, Outcome);
      Ok := Ok and then Outcome.Result = Cholesky.Factored;
   end Form_G;

   ---------------------------------------------------------------------
   --  The free variables and the held rows' multipliers.
   ---------------------------------------------------------------------

   --  From's x with each held variable at its bound, and From's
   --  multipliers on the held rows.
   procedure Start
     (Pr : Problem; Work : Workspace; From : State; Cand : out State)
   with
     Pre =>
       Fits_Work (Pr, Work)
       and then Fits_State (Pr, From)
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
      for R in 1 .. Pr.K loop
         Cand.Y_Row (R) :=
           (if Is_Held_Row (Work, R) then From.Y_Row (R) else 0);
      end loop;
   end Start;

   --  A refinement's working vectors: the held rows' gaps, and the step
   --  the refinement takes.
   type Correction
     (N : Index;
      K : Count)
   is record
      Row_Gap : Vector (1 .. K);
      Step    : Vector (1 .. N);
   end record;

   --  -(P x + q + A'lambda) at a free variable I.
   function Stationarity
     (Pr : Problem; Work : Workspace; Cand : State; I : Index) return Wide
   is (-(Round_Shift (Row_Vector_Dot (Pr.P, I, Cand.X, 1, Pr.N))
         + Wide (Pr.Q (I))
         + Round_Shift (Column_Vector_Dot (Work.A, I, Cand.Y_Row))))
   with
     Pre =>
       Fits_Work (Pr, Work) and then Fits_State (Pr, Cand) and then I <= Pr.N;

   --  The bound a held row R is held at, less E x.
   function Row_Gap_Of
     (Pr : Problem; Work : Workspace; Cand : State; R : Index) return Wide
   is (Wide (Bound_Of (Work.Row_Side (R), Pr.Row_Lo (R), Pr.Row_Hi (R)))
       - Certificate.Row_Of (Pr, R, Cand.X))
   with
     Pre =>
       Fits_Work (Pr, Work) and then Fits_State (Pr, Cand) and then R <= Pr.K;

   --  The held rows' gaps, and the right side of the regularized step:
   --  delta (-(P x + q + A'lambda)) + A' gap over the free variables.
   procedure Right_Side
     (Pr   : Problem;
      Work : Workspace;
      Cand : State;
      C    : in out Correction;
      Ok   : in out Boolean)
   with
     Pre =>
       Fits_Work (Pr, Work)
       and then Fits_State (Pr, Cand)
       and then C.N = Pr.N
       and then C.K = Pr.K
   is
      Pull : Val := 0;
   begin
      for R in 1 .. Pr.K loop
         C.Row_Gap (R) := 0;
         if Is_Held_Row (Work, R) then
            Store (Row_Gap_Of (Pr, Work, Cand, R), C.Row_Gap (R), Ok);
         end if;
      end loop;
      for I in 1 .. Pr.N loop
         C.Step (I) := 0;
         if Is_Free (Work, I) then
            Store (Stationarity (Pr, Work, Cand, I), Pull, Ok);
            Store
              (Scaled (Pull, -Delta_Shift)
               + Round_Shift (Column_Vector_Dot (Work.A, I, C.Row_Gap)),
               C.Step (I),
               Ok);
         end if;
      end loop;
   end Right_Side;

   --  The step taken: x moves by it, and each held row's multiplier by
   --  (A step - gap) / delta.
   procedure Take_Step
     (Pr   : Problem;
      Work : Workspace;
      C    : Correction;
      Cand : in out State;
      Ok   : in out Boolean)
   with
     Pre =>
       Fits_Work (Pr, Work)
       and then Fits_State (Pr, Cand)
       and then C.N = Pr.N
       and then C.K = Pr.K
   is
      Change : Val := 0;
   begin
      for I in 1 .. Pr.N loop
         Store (Wide (Cand.X (I)) + Wide (C.Step (I)), Cand.X (I), Ok);
      end loop;
      for R in 1 .. Pr.K loop
         if Is_Held_Row (Work, R) then
            Store
              (Round_Shift (Row_Vector_Dot (Work.A, R, C.Step, 1, Pr.N))
               - Wide (C.Row_Gap (R)),
               Change,
               Ok);
            Store
              (Wide (Cand.Y_Row (R)) + Scaled (Change, Delta_Shift),
               Cand.Y_Row (R),
               Ok);
         end if;
      end loop;
   end Take_Step;

   --  One refinement of x and the held rows' multipliers against the
   --  exact system, solved with the regularized one.
   procedure Refine_X
     (Pr : Problem; Work : Workspace; Cand : in out State; Ok : in out Boolean)
   with Pre => Fits_Work (Pr, Work) and then Fits_State (Pr, Cand)
   is
      C      : Correction (Pr.N, Pr.K) :=
        (Pr.N, Pr.K, [others => 0], [others => 0]);
      Solved : Cholesky.Solve_Result;
   begin
      Right_Side (Pr, Work, Cand, C, Ok);
      Cholesky.Solve (Work.S, Work.S_D, C.Step, Solved);
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
   --  free variables' residual -(P x + q + A'y_row), brought through A
   --  and solved with A A'.
   procedure Refine_Y
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
      Res    : Vector (1 .. Pr.N) := [others => 0];
      Rhs    : Vector (1 .. Pr.K) := [others => 0];
      Solved : Cholesky.Solve_Result;
   begin
      for I in 1 .. Pr.N loop
         if Is_Free (Work, I) then
            Store
              (-(Wide (Gr (I))
                 + Round_Shift (Column_Vector_Dot (Work.A, I, Cand.Y_Row))),
               Res (I),
               Ok);
         end if;
      end loop;
      for R in 1 .. Pr.K loop
         if Is_Held_Row (Work, R) then
            Store
              (Round_Shift (Row_Vector_Dot (Work.A, R, Res, 1, Pr.N)),
               Rhs (R),
               Ok);
         end if;
      end loop;
      Cholesky.Solve (Work.G, Work.G_D, Rhs, Solved);
      Ok := Ok and then Solved = Cholesky.Solved;
      for R in 1 .. Pr.K loop
         if Ok and then Is_Held_Row (Work, R) then
            Store (Wide (Cand.Y_Row (R)) + Wide (Rhs (R)), Cand.Y_Row (R), Ok);
         end if;
      end loop;
   end Refine_Y;

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
   begin
      Ok := True;
      Form_A (Pr, Work);
      Form_S (Pr, Work, Ok);
      Start (Pr, Work, From, Cand);
      for K in 1 .. X_Refinements loop
         exit when not Ok;
         Refine_X (Pr, Work, Cand, Ok);
      end loop;
      Form_G (Pr, Work, Ok);
      Gradient (Pr, Cand, Gr, Ok);
      for K in 1 .. Y_Refinements loop
         exit when not Ok;
         Refine_Y (Pr, Work, Gr, Cand, Ok);
      end loop;
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
         if not Is_Held_Row (Work, R) then
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
