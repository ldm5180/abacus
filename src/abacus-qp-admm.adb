with Abacus.Arith;    use Abacus.Arith;
with Abacus.Cholesky;
with Abacus.Matrices; use Abacus.Matrices;
with Abacus.Qp.Certificate;
with Abacus.Qp.Cones;
with Abacus.Qp.Scaling;
with Abacus.Vectors;

package body Abacus.Qp.Admm
  with SPARK_Mode
is

   use type Cholesky.Factor_Result;
   use type Cholesky.Solve_Result;

   ---------------------------------------------------------------------
   --  Forming and factoring.
   ---------------------------------------------------------------------

   --  Entry (I, J) of P plus Diagonal on the diagonal.
   function Plus_Diagonal
     (Pr : Problem; Diagonal : Wide; I, J : Index) return Wide
   is (Wide (Pr.P (I, J)) + (if I = J then Diagonal else 0))
   with
     Pre =>
       I in 1 .. Pr.N
       and then J in 1 .. Pr.N
       and then Diagonal in 0 .. 2 * Scaled_Bound;

   --  P plus Diagonal on its diagonal, its lower triangle into L; Ok is
   --  False when an entry does not fit.
   procedure Form_Plain
     (Pr : Problem; Diagonal : Wide; Work : in out Workspace; Ok : out Boolean)
   with Pre => Fits_Work (Pr, Work) and then Diagonal in 0 .. 2 * Scaled_Bound
   is
   begin
      Ok := True;
      for I in 1 .. Pr.N loop
         for J in 1 .. I loop
            Store (Plus_Diagonal (Pr, Diagonal, I, J), Work.L (I, J), Ok);
         end loop;
      end loop;
   end Form_Plain;

   --  The step of the general row at place P of Work's order.
   function Step_At (Pr : Problem; Work : Workspace; P : Index) return Shift
   is (if Work.Row_Order (P) <= Pr.K
       then Work.Row_Step (Work.Row_Order (P))
       else 0)
   with Pre => Fits_Work (Pr, Work) and then P <= Pr.K;

   --  Whether place P of Work's order ends a run of one step.
   function Ends_Run (Pr : Problem; Work : Workspace; P : Index) return Boolean
   is (P = Pr.K or else Step_At (Pr, Work, P + 1) /= Step_At (Pr, Work, P))
   with Pre => Fits_Work (Pr, Work) and then P <= Pr.K;

   --  A run's exact sum of products scaled by 2**S and rounded once to
   --  the grid.
   function Run_Term (Sum : Product; S : Shift) return Wide
   is (if S >= 0
       then Div_Round (Sum, Powers_Of_Two (Frac - S))
       else Div_Round (Sum, One * Power_Of (-S)));

   --  How far an entry of E'RE is held: past the values whatever else is
   --  added, so a sum that reaches it is refused by the store.
   Stepped_Bound : constant := 2**120;

   --  Entry (I, J) of E'RE, R the general rows' steps: the rows taken in
   --  Work's order, each run of one step summed exactly at 128 bits and
   --  rounded and scaled once.
   function Stepped_Column_Dot
     (Pr : Problem; Work : Workspace; I, J : Index) return Wide
   with
     Pre  => Fits_Work (Pr, Work) and then I <= Pr.N and then J <= Pr.N,
     Post => Stepped_Column_Dot'Result in -Stepped_Bound .. Stepped_Bound
   is
      Sum : Wide := 0;
      Run : Wide := 0;
      R   : Index;
   begin
      for P in 1 .. Pr.K loop
         R := Work.Row_Order (P);
         if R <= Pr.K then
            Run := Run + Wide (Pr.E (R, I)) * Wide (Pr.E (R, J));
         end if;
         if Ends_Run (Pr, Work, P) then
            Sum :=
              Wide'Max
                (-Stepped_Bound,
                 Wide'Min
                   (Stepped_Bound,
                    Sum + Run_Term (Run, Step_At (Pr, Work, P))));
            Run := 0;
         end if;
         pragma
           Loop_Invariant
             (Run
              in -(Wide (P) * Vectors.Term_Bound)
               .. Wide (P) * Vectors.Term_Bound);
         pragma Loop_Invariant (Sum in -Stepped_Bound .. Stepped_Bound);
      end loop;
      return Sum;
   end Stepped_Column_Dot;

   --  2**S, as a value.
   function Unit_Shift (S : Shift) return Wide
   is (Scaled (Val (One), S));

   --  The steps' diagonal at variable I: its proximal term and its box
   --  row's step.
   function Step_Diagonal (Work : Workspace; I : Index) return Wide
   is (Unit_Shift (Work.Prox_Step (I)) + Unit_Shift (Work.Box_Step (I)))
   with Pre => I <= Work.N;

   --  The lower triangle of P + diag (sigma + rho) + E'RE into L, each
   --  row and variable at its own step; Ok is False when an entry does
   --  not fit.
   procedure Form_Stepped
     (Pr : Problem; Work : in out Workspace; Ok : out Boolean)
   with Pre => Fits_Work (Pr, Work)
   is
   begin
      Ok := True;
      for I in 1 .. Pr.N loop
         for J in 1 .. I loop
            Store
              (Wide (Pr.P (I, J))
               + (if I = J then Step_Diagonal (Work, I) else 0)
               + Stepped_Column_Dot (Pr, Work, I, J),
               Work.L (I, J),
               Ok);
         end loop;
      end loop;
   end Form_Stepped;

   --  A workspace cleared: zeros, unit pivots, nothing held.
   procedure Clear (Work : out Workspace) is
   begin
      Work.L := [others => [others => 0]];
      Work.D := [others => 1];
      Work.Box_Step := [others => 0];
      Work.Row_Step := [others => 0];
      Work.Prox_Step := [others => 0];
      Work.Row_Order := [others => 1];
      Work.Box_Side := [others => Free];
      Work.Row_Side := [others => Free];
      Work.Free_At := [others => 1];
      Work.Row_At := [others => 1];
      Work.Free_Count := 0;
      Work.Row_Count := 0;
      Work.A := [others => [others => 0]];
      Work.S := [others => [others => 0]];
      Work.S_D := [others => 1];
      Work.G := [others => [others => 0]];
      Work.G_D := [others => 1];
   end Clear;

   procedure Prepare
     (Pr     : Problem;
      S      : Settings;
      Work   : out Workspace;
      Result : out Prepare_Result)
   is
      Ok      : Boolean;
      Outcome : Cholesky.Factor_Outcome;
   begin
      Clear (Work);
      Result := Out_Of_Range;
      Form_Plain (Pr, Unit_Shift (S.Sigma_Shift), Work, Ok);
      if not Ok then
         return;
      end if;
      Cholesky.Factor (Work.L, Work.D, 1, Outcome);
      if Outcome.Result /= Cholesky.Factored then
         Result :=
           (if Outcome.Result = Cholesky.Out_Of_Range
            then Out_Of_Range
            else Not_Convex);
         return;
      end if;
      Scaling.Set_Steps (Pr, S, Work);
      Form_Stepped (Pr, Work, Ok);
      if Ok then
         Cholesky.Factor (Work.L, Work.D, 1, Outcome);
         Result :=
           (if Outcome.Result = Cholesky.Factored
            then Ready
            else Out_Of_Range);
      end if;
   end Prepare;

   ---------------------------------------------------------------------
   --  One iteration.
   ---------------------------------------------------------------------

   --  rho_row z_row - y_row: what the general rows add to the right side
   --  through E'.
   procedure Row_Pull
     (Pr   : Problem;
      Work : Workspace;
      St   : State;
      V    : out Vector;
      Ok   : in out Boolean)
   with
     Pre =>
       Fits_Work (Pr, Work)
       and then Fits_State (Pr, St)
       and then V'First = 1
       and then V'Last = Pr.K
   is
   begin
      V := [others => 0];
      for R in 1 .. Pr.K loop
         Store
           (Scaled (St.Z_Row (R), Work.Row_Step (R)) - Wide (St.Y_Row (R)),
            V (R),
            Ok);
      end loop;
   end Row_Pull;

   --  sigma x - q + rho z - y + E'(rho_row z_row - y_row).
   procedure Right_Side
     (Pr   : Problem;
      Work : Workspace;
      St   : State;
      B    : out Vector;
      Ok   : in out Boolean)
   with
     Pre =>
       Fits_Work (Pr, Work)
       and then Fits_State (Pr, St)
       and then B'First = 1
       and then B'Last = Pr.N
   is
      V : Vector (1 .. Pr.K);
   begin
      B := [others => 0];
      Row_Pull (Pr, Work, St, V, Ok);
      for I in 1 .. Pr.N loop
         Store
           (Scaled (St.X (I), Work.Prox_Step (I))
            - Wide (Pr.Q (I))
            + Scaled (St.Z (I), Work.Box_Step (I))
            - Wide (St.Y (I))
            + Round_Shift (Column_Vector_Dot (Pr.E, I, V)),
            B (I),
            Ok);
      end loop;
   end Right_Side;

   --  Z relaxed toward Tilde: Z + Alpha (Tilde - Z).
   procedure Relax (Tilde, Z, Alpha : Val; Hat : out Val; Ok : in out Boolean)
   is
      Step : Val := 0;
   begin
      Hat := 0;
      Store (Wide (Tilde) - Wide (Z), Step, Ok);
      Store (Wide (Z) + Product_Of (Alpha, Step), Hat, Ok);
   end Relax;

   --  The dual step to a projected New_Z from the relaxed Hat: Y grows by
   --  2**Rho (Hat - New_Z).
   procedure Settle
     (Hat, New_Z : Val; Rho : Shift; Y : in out Val; Ok : in out Boolean)
   is
      Step : Val := 0;
   begin
      Store (Wide (Hat) - Wide (New_Z), Step, Ok);
      Store (Wide (Y) + Scaled (Step, Rho), Y, Ok);
   end Settle;

   --  What one row's step needs: its new value Tilde, its bounds, the
   --  relaxation and the row's step size.
   type Row_Step is record
      Tilde : Val;
      Lo    : Val;
      Hi    : Val;
      Alpha : Val;
      Rho   : Shift;
   end record;

   --  One row's relaxed projection onto its interval and dual update.
   procedure Update (R : Row_Step; Z, Y : in out Val; Ok : in out Boolean) is
      Hat   : Val;
      New_Z : Val;
   begin
      Relax (R.Tilde, Z, R.Alpha, Hat, Ok);
      New_Z :=
        Clamp (Wide (Hat) + Scaled (Y, -R.Rho), R.Lo, Val'Max (R.Lo, R.Hi));
      Settle (Hat, New_Z, R.Rho, Y, Ok);
      Z := New_Z;
   end Update;

   --  An iteration's step in progress: the relaxation; each general
   --  row's relaxed value and the value it is projected to; and whether
   --  every value stayed in range.
   type Step_Work (K : Count) is record
      Alpha : Relaxation;
      Hat   : Vector (1 .. K);
      New_Z : Vector (1 .. K);
      Ok    : Boolean;
   end record;

   --  x relaxed toward the solve's Tilde, then the box rows updated.
   procedure Update_Box
     (Pr    : Problem;
      Work  : Workspace;
      Tilde : Vector;
      St    : in out State;
      W     : in out Step_Work)
   with
     Pre =>
       Fits_Work (Pr, Work)
       and then Fits_State (Pr, St)
       and then Tilde'First = 1
       and then Tilde'Last = Pr.N
   is
      Step : Val := 0;
   begin
      for I in 1 .. Pr.N loop
         Store (Wide (Tilde (I)) - Wide (St.X (I)), Step, W.Ok);
         Store (Wide (St.X (I)) + Product_Of (W.Alpha, Step), St.X (I), W.Ok);
         Update
           ((Tilde (I), Pr.Lo (I), Pr.Hi (I), W.Alpha, Work.Box_Step (I)),
            St.Z (I),
            St.Y (I),
            W.Ok);
      end loop;
   end Update_Box;

   --  Each general row's relaxed value, from E times the solve's Tilde.
   procedure Relax_Rows
     (Pr : Problem; Tilde : Vector; St : State; W : in out Step_Work)
   with
     Pre =>
       Fits_State (Pr, St)
       and then Tilde'First = 1
       and then Tilde'Last = Pr.N
       and then W.K = Pr.K
   is
      Ex : Val := 0;
   begin
      for R in 1 .. Pr.K loop
         Store (Certificate.Row_Of (Pr, R, Tilde), Ex, W.Ok);
         Relax (Ex, St.Z_Row (R), W.Alpha, W.Hat (R), W.Ok);
      end loop;
   end Relax_Rows;

   --  Where each general row is projected from: Hat + y_row / rho_row,
   --  clamped into an interval row's bounds, less the vertex in a cone.
   procedure Shifted_Rows
     (Pr : Problem; Work : Workspace; St : State; W : in out Step_Work)
   with
     Pre =>
       Fits_Work (Pr, Work) and then Fits_State (Pr, St) and then W.K = Pr.K
   is
      Sum : Wide;
   begin
      for R in 1 .. Pr.K loop
         Sum := Wide (W.Hat (R)) + Scaled (St.Y_Row (R), -Work.Row_Step (R));
         if Cones.In_Cone (Pr, R) then
            Store (Sum - Wide (Pr.Row_Lo (R)), W.New_Z (R), W.Ok);
         else
            W.New_Z (R) :=
              Clamp
                (Sum, Pr.Row_Lo (R), Val'Max (Pr.Row_Lo (R), Pr.Row_Hi (R)));
         end if;
      end loop;
   end Shifted_Rows;

   --  Each cone's run projected onto the cone, and its vertex added back.
   procedure Project_Cones (Pr : Problem; W : in out Step_Work)
   with Pre => W.K = Pr.K
   is
   begin
      for R in 1 .. Pr.K loop
         if Cones.Starts_Cone (Pr, R) then
            Cones.Project (W.New_Z, R, Cones.Cone_Last (Pr, R), W.Ok);
         end if;
      end loop;
      for R in 1 .. Pr.K loop
         if Cones.In_Cone (Pr, R) then
            Store
              (Wide (W.New_Z (R)) + Wide (Pr.Row_Lo (R)), W.New_Z (R), W.Ok);
         end if;
      end loop;
   end Project_Cones;

   --  The general rows, relaxed into W, projected onto an interval or a
   --  cone, and their duals stepped.
   procedure Update_Rows
     (Pr : Problem; Work : Workspace; St : in out State; W : in out Step_Work)
   with
     Pre =>
       Fits_Work (Pr, Work) and then Fits_State (Pr, St) and then W.K = Pr.K
   is
   begin
      Shifted_Rows (Pr, Work, St, W);
      Project_Cones (Pr, W);
      for R in 1 .. Pr.K loop
         Settle
           (W.Hat (R), W.New_Z (R), Work.Row_Step (R), St.Y_Row (R), W.Ok);
      end loop;
      St.Z_Row := W.New_Z;
   end Update_Rows;

   procedure Iterate
     (Pr   : Problem;
      S    : Settings;
      Work : Workspace;
      St   : in out State;
      Ok   : out Boolean)
   is
      B      : Vector (1 .. Pr.N);
      Solved : Cholesky.Solve_Result;
      W      : Step_Work (Pr.K) :=
        (K     => Pr.K,
         Alpha => S.Alpha,
         Hat   => [others => 0],
         New_Z => [others => 0],
         Ok    => True);
   begin
      Ok := True;
      Right_Side (Pr, Work, St, B, Ok);
      if Ok then
         Cholesky.Solve (Work.L, Work.D, B, Solved);
         Ok := Solved = Cholesky.Solved;
      end if;
      if Ok then
         Relax_Rows (Pr, B, St, W);
         Update_Rows (Pr, Work, St, W);
         Update_Box (Pr, Work, B, St, W);
         Ok := W.Ok;
         St.Iterations :=
           (if St.Iterations < Natural'Last
            then St.Iterations + 1
            else Natural'Last);
      end if;
   end Iterate;

   ---------------------------------------------------------------------
   --  Checks.
   ---------------------------------------------------------------------

   function Larger (A : Wide; B : Wide) return Wide
   is (if B > A then B else A);

   --  |A - B| for two values.
   function Gap (A, B : Val) return Wide
   is (if A >= B then Wide (A) - Wide (B) else Wide (B) - Wide (A));

   function Primal (Pr : Problem; St : State) return Wide
   with Pre => Fits_State (Pr, St)
   is
      M : Wide := 0;
   begin
      for I in 1 .. Pr.N loop
         M := Larger (M, Gap (St.X (I), St.Z (I)));
         pragma Loop_Invariant (M in 0 .. 2 * Val_Bound);
      end loop;
      for R in 1 .. Pr.K loop
         M :=
           Larger
             (M,
              Certificate.Magnitude
                (Certificate.Row_Of (Pr, R, St.X) - Wide (St.Z_Row (R))));
      end loop;
      return M;
   end Primal;

   function Residuals (Pr : Problem; St : State) return Residual
   is ((Primal => Primal (Pr, St),
        Dual   => Certificate.Dual_Residual (Pr, St)));

   function Same (A, B : State) return Boolean
   is (A.X = B.X
       and then A.Z = B.Z
       and then A.Y = B.Y
       and then A.Z_Row = B.Z_Row
       and then A.Y_Row = B.Y_Row);

   --  Whether a polish is due at St: asked for, at a multiple of its
   --  interval, and both residuals within its reach.
   function Polish_Due (S : Settings; St : State; R : Residual) return Boolean
   is (S.Polish_Every > 0
       and then St.Iterations mod S.Polish_Every = 0
       and then R.Primal <= Wide (S.Polish_Below)
       and then R.Dual <= Wide (S.Polish_Below));

   procedure Check
     (Pr   : Problem;
      S    : Settings;
      St   : State;
      Last : in out State;
      V    : out Verdict)
   is
      R : constant Residual := Residuals (Pr, St);
   begin
      if R.Primal <= Wide (S.Tol.Primal) and then R.Dual <= Wide (S.Tol.Dual)
      then
         V := Converged;
      elsif Certificate.Infeasible (Pr, St, Last, S.Infeasible) then
         V := Primal_Infeasible;
      elsif Certificate.Unbounded (Pr, St, Last, S.Infeasible) then
         V := Dual_Infeasible;
      elsif Same (St, Last) then
         V := Held;
      else
         V := (if Polish_Due (S, St, R) then Near else Moving);
         Last := St;
      end if;
   end Check;

end Abacus.Qp.Admm;
