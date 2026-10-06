with Spike.Grid;
with Spike.Kernels; use Spike.Kernels;
with Spike.Linear;

package body Spike.Admm
  with SPARK_Mode
is

   package G is new Spike.Grid (Frac);
   package Lin is new Spike.Linear (Frac);

   use type Lin.Factor_Result;
   use type Lin.Solve_Result;

   One : constant Wide := G.One;

   function Mul (A, B : Val) return Wide renames G.Mul;

   --  2**K for a step's exponent, bounded by its element subtype so a
   --  product with a value has a bound the prover can see.
   subtype Power is Wide range 1 .. 2**Shift'Last;
   type Power_Table is array (0 .. Shift'Last) of Power;

   Powers : constant Power_Table := [for K in 0 .. Shift'Last => 2**K];

   Shifted_Bound : constant := Val_Bound * 2**Shift'Last;

   --  V times 2**S, rounded half away from zero when S is negative.
   function Shifted (V : Val; S : Shift) return Wide
   is (if S >= 0
       then Wide (V) * Powers (S)
       else Div_Round (Wide (V), Powers (-S)))
   with Post => Shifted'Result in -Shifted_Bound .. Shifted_Bound;

   function Clamp (W : Wide; Lo, Hi : Val) return Val
   is (if W <= Wide (Lo) then Lo elsif W >= Wide (Hi) then Hi else Val (W));

   --  Entry (I, J) of P + sigma I + rho I.
   function Shifted_P (Pr : Problem; S : Settings; I, J : Index) return Wide
   is (Wide (Pr.P (I, J))
       + (if I = J
          then
            Shifted (Val (One), S.Sigma_Shift)
            + Shifted (Val (One), S.Rho_Shift)
          else 0))
   with Pre => I in 1 .. Pr.N and then J in 1 .. Pr.N;

   procedure Prepare
     (Pr     : Problem;
      S      : Settings;
      F      : out Factored;
      Result : out Prepare_Result)
   is
      Ok      : Boolean := True;
      Outcome : Lin.Factor_Outcome;
      Ee      : Val := 0;
   begin
      F.L := [others => [others => 0]];
      F.D := [others => 1];
      for I in 1 .. Pr.N loop
         for J in 1 .. I loop
            Store (G.Round (Dot_Columns (Pr.E, I, J)), Ee, Ok);
            Store
              (Shifted_P (Pr, S, I, J) + Shifted (Ee, S.Row_Shift),
               F.L (I, J),
               Ok);
         end loop;
      end loop;
      if not Ok then
         Result := Out_Of_Range;
         return;
      end if;
      Lin.Factor (F.L, F.D, 1, Outcome);
      Result :=
        (if Outcome.Result = Lin.Factored
         then Ready
         else Not_Positive_Definite);
   end Prepare;

   --  rho_row z_row - y_row: what the general rows add to the right side
   --  through E'.
   procedure Row_Pull
     (Pr : Problem;
      S  : Settings;
      St : State;
      V  : out Vector;
      Ok : in out Boolean)
   with
     Pre =>
       St.K = Pr.K
       and then St.N = Pr.N
       and then V'First = 1
       and then V'Last = Pr.K
   is
   begin
      V := [others => 0];
      for R in 1 .. Pr.K loop
         Store
           (Shifted (St.Z_Row (R), S.Row_Shift) - Wide (St.Y_Row (R)),
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
   with
     Pre =>
       St.K = Pr.K
       and then St.N = Pr.N
       and then B'First = 1
       and then B'Last = Pr.N
   is
      V : Vector (1 .. Pr.K);
   begin
      B := [others => 0];
      Row_Pull (Pr, S, St, V, Ok);
      for I in 1 .. Pr.N loop
         Store
           (Shifted (St.X (I), S.Sigma_Shift)
            - Wide (Pr.Q (I))
            + Shifted (St.Z (I), S.Rho_Shift)
            - Wide (St.Y (I))
            + G.Round (Dot_Column (Pr.E, I, V)),
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
      Store (Wide (Z) + Mul (R.Alpha, Step), Hat, Ok);
      New_Z := Clamp (Wide (Hat) + Shifted (Y, -R.Rho), R.Lo, R.Hi);
      Store (Wide (Hat) - Wide (New_Z), Step, Ok);
      Store (Wide (Y) + Shifted (Step, R.Rho), Y, Ok);
      Z := New_Z;
   end Update;

   --  x relaxed toward the solve's Tilde, then the box rows updated.
   procedure Update_Box
     (Pr    : Problem;
      S     : Settings;
      Tilde : Vector;
      St    : in out State;
      Ok    : in out Boolean)
   with Pre => St.N = Pr.N and then Tilde'First = 1 and then Tilde'Last = Pr.N
   is
      Step : Val := 0;
   begin
      for I in 1 .. Pr.N loop
         Store (Wide (Tilde (I)) - Wide (St.X (I)), Step, Ok);
         Store (Wide (St.X (I)) + Mul (S.Alpha, Step), St.X (I), Ok);
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
       St.N = Pr.N
       and then St.K = Pr.K
       and then Tilde'First = 1
       and then Tilde'Last = Pr.N
   is
      Ex : Val := 0;
   begin
      for R in 1 .. Pr.K loop
         Store (G.Round (Dot (Pr.E, R, Tilde, 1, Pr.N)), Ex, Ok);
         Update
           ((Ex, Pr.Row_Lo (R), Pr.Row_Hi (R), S.Alpha, S.Row_Shift),
            St.Z_Row (R),
            St.Y_Row (R),
            Ok);
      end loop;
   end Update_Rows;

   procedure Iterate
     (Pr : Problem;
      S  : Settings;
      F  : Factored;
      St : in out State;
      Ok : out Boolean)
   is
      B      : Vector (1 .. Pr.N);
      Solved : Lin.Solve_Result;
   begin
      Ok := True;
      Right_Side (Pr, S, St, B, Ok);
      if Ok then
         Lin.Solve (F.L, F.D, B, Solved);
         Ok := Solved = Lin.Solved;
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

   function Larger (A : Wide; B : Wide) return Wide
   is (if B > A then B else A);

   function Magnitude (W : Wide) return Wide
   is (if W < 0 then -W else W)
   with Pre => W > Wide'First;

   function Primal (Pr : Problem; St : State) return Wide
   with Pre => St.N = Pr.N and then St.K = Pr.K
   is
      M : Wide := 0;
   begin
      for I in 1 .. Pr.N loop
         M := Larger (M, Magnitude (Wide (St.X (I)) - Wide (St.Z (I))));
      end loop;
      for R in 1 .. Pr.K loop
         M :=
           Larger
             (M,
              Magnitude
                (G.Round (Dot (Pr.E, R, St.X, 1, Pr.N))
                 - Wide (St.Z_Row (R))));
      end loop;
      return M;
   end Primal;

   function Dual (Pr : Problem; St : State) return Wide
   with Pre => St.N = Pr.N and then St.K = Pr.K
   is
      M : Wide := 0;
   begin
      for I in 1 .. Pr.N loop
         M :=
           Larger
             (M,
              Magnitude
                (G.Round (Dot (Pr.P, I, St.X, 1, Pr.N))
                 + Wide (Pr.Q (I))
                 + Wide (St.Y (I))
                 + G.Round (Dot_Column (Pr.E, I, St.Y_Row))));
      end loop;
      return M;
   end Dual;

   function Residuals (Pr : Problem; St : State) return Residual
   is ((Primal => Primal (Pr, St), Dual => Dual (Pr, St)));

   function Same (A, B : State) return Boolean
   is (A.X = B.X
       and then A.Z = B.Z
       and then A.Y = B.Y
       and then A.Z_Row = B.Z_Row
       and then A.Y_Row = B.Y_Row);

   --  Checks St against the tolerances and against the last checked
   --  state Last; Done when the iteration should stop.
   procedure Check
     (Pr     : Problem;
      S      : Settings;
      St     : State;
      Last   : in out State;
      Result : out Result_Kind)
   with
     Pre =>
       St.N = Pr.N
       and then St.K = Pr.K
       and then Last.N = Pr.N
       and then Last.K = Pr.K
   is
      R : constant Residual := Residuals (Pr, St);
   begin
      if R.Primal <= Wide (S.Tol_Primal) and then R.Dual <= Wide (S.Tol_Dual)
      then
         Result := Converged;
      elsif Same (St, Last) then
         Result := Stalled;
      else
         Result := Exhausted;
         Last := St;
      end if;
   end Check;

   procedure Solve
     (Pr : Problem; S : Settings; St : in out State; Result : out Result_Kind)
   is
      F     : Factored (Pr.N);
      Last  : State := St;
      Ok    : Boolean;
      Setup : Prepare_Result;
   begin
      Prepare (Pr, S, F, Setup);
      if Setup /= Ready then
         Result :=
           (if Setup = Out_Of_Range then Diverged else Not_Positive_Definite);
         return;
      end if;
      Result := Exhausted;
      for It in 1 .. S.Max_Iter loop
         Iterate (Pr, S, F, St, Ok);
         if not Ok then
            Result := Diverged;
            return;
         end if;
         if It mod S.Check_Every = 0 then
            Check (Pr, S, St, Last, Result);
            exit when Result /= Exhausted;
         end if;
      end loop;
   end Solve;

end Spike.Admm;
