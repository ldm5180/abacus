with Abacus.Arith;    use Abacus.Arith;
with Abacus.Cholesky;
with Abacus.Matrices; use Abacus.Matrices;
with Abacus.Qp.Certificate;

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

   --  What is added to P before it is factored: a diagonal, and the
   --  general rows' E'E times 2**Row when With_Rows.
   type Additions is record
      Diagonal  : Wide;
      Row       : Shift;
      With_Rows : Boolean;
   end record;

   --  The lower triangle of P + the additions into L; Ok is False when an
   --  entry does not fit.
   procedure Form
     (Pr : Problem; A : Additions; Work : in out Workspace; Ok : out Boolean)
   with
     Pre => Fits_Work (Pr, Work) and then A.Diagonal in 0 .. 2 * Scaled_Bound
   is
      Ee : Val := 0;
   begin
      Ok := True;
      for I in 1 .. Pr.N loop
         for J in 1 .. I loop
            if A.With_Rows then
               Store (Round_Shift (Column_Dot (Pr.E, I, J)), Ee, Ok);
            end if;
            Store
              (Plus_Diagonal (Pr, A.Diagonal, I, J) + Scaled (Ee, A.Row),
               Work.L (I, J),
               Ok);
         end loop;
      end loop;
   end Form;

   --  A workspace cleared: zeros, unit pivots, nothing held.
   procedure Clear (Work : out Workspace) is
   begin
      Work.L := [others => [others => 0]];
      Work.D := [others => 1];
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

   function Unit_Shift (S : Shift) return Wide
   is (Scaled (Val (One), S));

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
      Form (Pr, (Unit_Shift (S.Sigma_Shift), 0, False), Work, Ok);
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
      Form
        (Pr,
         (Unit_Shift (S.Sigma_Shift) + Unit_Shift (S.Rho_Shift),
          S.Row_Shift,
          True),
         Work,
         Ok);
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
     (Pr : Problem;
      S  : Settings;
      St : State;
      V  : out Vector;
      Ok : in out Boolean)
   with Pre => Fits_State (Pr, St) and then V'First = 1 and then V'Last = Pr.K
   is
   begin
      V := [others => 0];
      for R in 1 .. Pr.K loop
         Store
           (Scaled (St.Z_Row (R), S.Row_Shift) - Wide (St.Y_Row (R)),
            V (R),
            Ok);
      end loop;
   end Row_Pull;

   --  sigma x - q + rho z - y + E'(rho_row z_row - y_row).
   procedure Right_Side
     (Pr : Problem;
      S  : Settings;
      St : State;
      B  : out Vector;
      Ok : in out Boolean)
   with Pre => Fits_State (Pr, St) and then B'First = 1 and then B'Last = Pr.N
   is
      V : Vector (1 .. Pr.K);
   begin
      B := [others => 0];
      Row_Pull (Pr, S, St, V, Ok);
      for I in 1 .. Pr.N loop
         Store
           (Scaled (St.X (I), S.Sigma_Shift)
            - Wide (Pr.Q (I))
            + Scaled (St.Z (I), S.Rho_Shift)
            - Wide (St.Y (I))
            + Round_Shift (Column_Vector_Dot (Pr.E, I, V)),
            B (I),
            Ok);
      end loop;
   end Right_Side;

   --  What one row's step needs: its new value Tilde, its bounds, the
   --  relaxation and the row's step size.
   type Row_Step is record
      Tilde : Val;
      Lo    : Val;
      Hi    : Val;
      Alpha : Val;
      Rho   : Shift;
   end record;

   --  One row's relaxed projection and dual update.
   procedure Update (R : Row_Step; Z, Y : in out Val; Ok : in out Boolean) is
      Hat   : Val := 0;
      Step  : Val := 0;
      New_Z : Val;
   begin
      Store (Wide (R.Tilde) - Wide (Z), Step, Ok);
      Store (Wide (Z) + Product_Of (R.Alpha, Step), Hat, Ok);
      New_Z :=
        Clamp (Wide (Hat) + Scaled (Y, -R.Rho), R.Lo, Val'Max (R.Lo, R.Hi));
      Store (Wide (Hat) - Wide (New_Z), Step, Ok);
      Store (Wide (Y) + Scaled (Step, R.Rho), Y, Ok);
      Z := New_Z;
   end Update;

   --  x relaxed toward the solve's Tilde, then the box rows updated.
   procedure Update_Box
     (Pr    : Problem;
      S     : Settings;
      Tilde : Vector;
      St    : in out State;
      Ok    : in out Boolean)
   with
     Pre =>
       Fits_State (Pr, St) and then Tilde'First = 1 and then Tilde'Last = Pr.N
   is
      Step : Val := 0;
   begin
      for I in 1 .. Pr.N loop
         Store (Wide (Tilde (I)) - Wide (St.X (I)), Step, Ok);
         Store (Wide (St.X (I)) + Product_Of (S.Alpha, Step), St.X (I), Ok);
         Update
           ((Tilde (I), Pr.Lo (I), Pr.Hi (I), S.Alpha, S.Rho_Shift),
            St.Z (I),
            St.Y (I),
            Ok);
      end loop;
   end Update_Box;

   --  The general rows updated from E times the solve's Tilde.
   procedure Update_Rows
     (Pr    : Problem;
      S     : Settings;
      Tilde : Vector;
      St    : in out State;
      Ok    : in out Boolean)
   with
     Pre =>
       Fits_State (Pr, St) and then Tilde'First = 1 and then Tilde'Last = Pr.N
   is
      Ex : Val := 0;
   begin
      for R in 1 .. Pr.K loop
         Store (Certificate.Row_Of (Pr, R, Tilde), Ex, Ok);
         Update
           ((Ex, Pr.Row_Lo (R), Pr.Row_Hi (R), S.Alpha, S.Row_Shift),
            St.Z_Row (R),
            St.Y_Row (R),
            Ok);
      end loop;
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
   begin
      Ok := True;
      Right_Side (Pr, S, St, B, Ok);
      if Ok then
         Cholesky.Solve (Work.L, Work.D, B, Solved);
         Ok := Solved = Cholesky.Solved;
      end if;
      if Ok then
         Update_Rows (Pr, S, B, St, Ok);
         Update_Box (Pr, S, B, St, Ok);
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
