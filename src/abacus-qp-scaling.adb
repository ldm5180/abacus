with Abacus.Arith;
with Abacus.Qp.Cones;

package body Abacus.Qp.Scaling
  with SPARK_Mode
is

   function Exponent_Of (V : Val) return Exponent is
      Size : constant Wide := (if V < 0 then -Wide (V) else Wide (V));
      Lo   : Natural := 0;
      Hi   : Natural := Val_Bits;
      Mid  : Natural;
   begin
      while Lo < Hi loop
         pragma Loop_Invariant (Lo < Hi and then Hi <= Val_Bits);
         pragma Loop_Variant (Decreases => Hi - Lo);
         Mid := (Lo + Hi + 1) / 2;
         if Size >= Arith.Powers_Of_Two (Mid) then
            Lo := Mid;
         else
            Hi := Mid - 1;
         end if;
      end loop;
      return Lo - Frac;
   end Exponent_Of;

   ---------------------------------------------------------------------
   --  The scales, as exponents of two.
   ---------------------------------------------------------------------

   --  How far a scale may go: past it a step would be clamped anyway.
   Scale_Bound : constant := 64;
   subtype Scale is Integer range -Scale_Bound .. Scale_Bound;
   type Scales is array (Index range <>) of Scale;

   --  The scales of the variables, of their box rows and of the general
   --  rows, and of the cost.
   type Equilibration
     (N : Index;
      K : Count)
   is record
      Var  : Scales (1 .. N);
      Box  : Scales (1 .. N);
      Row  : Scales (1 .. K);
      Cost : Scale;
   end record;

   --  The exponent of a scaled entry's magnitude, and of an empty
   --  maximum: below every entry's.
   Level_Bound : constant := 4 * Scale_Bound + Frac + Most;
   subtype Level is Integer range -Level_Bound .. Level_Bound;
   Empty       : constant Level := Level'First;

   function Larger (A, B : Level) return Level
   is (if B > A then B else A);

   --  An entry's level once its row is scaled by Row and its column by
   --  Column; Empty for a zero.
   function Entry_Level (V : Val; Row, Column : Scale) return Level
   is (if V = 0 then Empty else Exponent_Of (V) + Row + Column);

   --  The largest level of column J of P and E, and of its box row, the
   --  column scaled by Column.
   function Column_Level
     (Pr : Problem; Q : Equilibration; J : Index; Column : Scale) return Level
   with Pre => Q.N = Pr.N and then Q.K = Pr.K and then J <= Pr.N
   is
      M : Level := Q.Box (J) + Column;
   begin
      for I in 1 .. Pr.N loop
         M := Larger (M, Entry_Level (Pr.P (I, J), Q.Var (I), Column));
      end loop;
      for R in 1 .. Pr.K loop
         M := Larger (M, Entry_Level (Pr.E (R, J), Q.Row (R), Column));
      end loop;
      return M;
   end Column_Level;

   --  The largest level of general row R.
   function Row_Level (Pr : Problem; Q : Equilibration; R : Index) return Level
   with Pre => Q.N = Pr.N and then Q.K = Pr.K and then R <= Pr.K
   is
      M : Level := Empty;
   begin
      for J in 1 .. Pr.N loop
         M := Larger (M, Entry_Level (Pr.E (R, J), Q.Row (R), Q.Var (J)));
      end loop;
      return M;
   end Row_Level;

   --  A scale moved by half a level the other way, so the level comes
   --  to within a factor of two of one; held to the scales.
   function Moved (S : Scale; L : Level) return Scale
   is (if L = Empty
       then S
       else Integer'Max (-Scale_Bound, Integer'Min (Scale_Bound, S - L / 2)));

   type Levels is array (Index range <>) of Level;

   --  Each general row's level, a cone's rows each taking the largest of
   --  the cone's, so they move together.
   procedure Row_Levels (Pr : Problem; Q : Equilibration; L : out Levels)
   with
     Pre =>
       Q.N = Pr.N
       and then Q.K = Pr.K
       and then L'First = 1
       and then L'Last = Pr.K
   is
      Last : Index;
      M    : Level;
   begin
      L := [others => Empty];
      for R in 1 .. Pr.K loop
         L (R) := Row_Level (Pr, Q, R);
      end loop;
      for R in 1 .. Pr.K loop
         if Cones.Starts_Cone (Pr, R) then
            Last := Cones.Cone_Last (Pr, R);
            M := Empty;
            for C in R .. Last loop
               M := Larger (M, L (C));
            end loop;
            L (R .. Last) := [others => M];
         end if;
      end loop;
   end Row_Levels;

   --  One pass of Ruiz's method: every level measured on the problem as
   --  scaled so far, then every scale moved.
   procedure Pass (Pr : Problem; Q : in out Equilibration)
   with Pre => Q.N = Pr.N and then Q.K = Pr.K
   is
      Columns : Levels (1 .. Pr.N) := [others => Empty];
      Rows    : Levels (1 .. Pr.K);
   begin
      for J in 1 .. Pr.N loop
         Columns (J) := Column_Level (Pr, Q, J, Q.Var (J));
      end loop;
      Row_Levels (Pr, Q, Rows);
      for J in 1 .. Pr.N loop
         Q.Box (J) := Moved (Q.Box (J), Q.Box (J) + Q.Var (J));
         Q.Var (J) := Moved (Q.Var (J), Columns (J));
      end loop;
      for R in 1 .. Pr.K loop
         Q.Row (R) := Moved (Q.Row (R), Rows (R));
      end loop;
   end Pass;

   --  The cost's scale for a scaled cost whose largest level is L: the
   --  one that brings it to one; none for a cost of zeros.
   function Cost_Of (L : Level) return Scale
   is (if L = Empty
       then 0
       else Integer'Max (-Scale_Bound, Integer'Min (Scale_Bound, -L)));

   --  The largest level of the scaled cost: of P, and of q.
   function Cost_Level (Pr : Problem; Q : Equilibration) return Level
   with Pre => Q.N = Pr.N and then Q.K = Pr.K
   is
      M : Level := Empty;
   begin
      for J in 1 .. Pr.N loop
         M := Larger (M, Entry_Level (Pr.Q (J), 0, Q.Var (J)));
         for I in 1 .. Pr.N loop
            M := Larger (M, Entry_Level (Pr.P (I, J), Q.Var (I), Q.Var (J)));
         end loop;
      end loop;
      return M;
   end Cost_Level;

   --  Pr's scales after Passes passes, and the cost's scale, which brings
   --  the scaled cost's largest entry to within a factor of two of one.
   function Equilibrated
     (Pr : Problem; Passes : Pass_Count) return Equilibration
   with
     Post => Equilibrated'Result.N = Pr.N and then Equilibrated'Result.K = Pr.K
   is
      Q : Equilibration (Pr.N, Pr.K) :=
        (N    => Pr.N,
         K    => Pr.K,
         Var  => [others => 0],
         Box  => [others => 0],
         Row  => [others => 0],
         Cost => 0);
   begin
      for P in 1 .. Passes loop
         Pass (Pr, Q);
      end loop;
      if Passes > 0 then
         Q.Cost := Cost_Of (Cost_Level (Pr, Q));
      end if;
      return Q;
   end Equilibrated;

   ---------------------------------------------------------------------
   --  The steps.
   ---------------------------------------------------------------------

   --  A step's shift: the setting's Base moved by an equilibrated
   --  Change, never past Base -- a larger step moves its multiplier in
   --  coarser units of the grid -- nor below the steps.
   function Held (Base : Shift; Change : Integer) return Shift
   is (Integer'Max (Shift'First, Integer'Min (Base, Base + Change)))
   with Pre => Change in -4 * Scale_Bound .. 4 * Scale_Bound;

   --  The general rows in the order of their steps, each step's rows in
   --  their own order.
   procedure Order_Rows (Pr : Problem; Work : in out Workspace)
   with Pre => Fits_Work (Pr, Work)
   is
      Next : Count := 0;
   begin
      Work.Row_Order := [others => 1];
      for S in Shift loop
         pragma Loop_Invariant (Next <= Pr.K);
         for R in 1 .. Pr.K loop
            if Work.Row_Step (R) = S and then Next < Pr.K then
               Next := Next + 1;
               Work.Row_Order (Next) := R;
            end if;
            pragma Loop_Invariant (Next <= Pr.K);
         end loop;
      end loop;
   end Order_Rows;

   procedure Set_Steps (Pr : Problem; S : Settings; Work : in out Workspace) is
      Q : constant Equilibration := Equilibrated (Pr, S.Equilibrate);
   begin
      for J in 1 .. Pr.N loop
         Work.Box_Step (J) := Held (S.Rho_Shift, 2 * Q.Box (J) - Q.Cost);
         Work.Prox_Step (J) := Held (S.Sigma_Shift, -(2 * Q.Var (J)) - Q.Cost);
      end loop;
      for R in 1 .. Pr.K loop
         Work.Row_Step (R) := Held (S.Row_Shift, 2 * Q.Row (R) - Q.Cost);
      end loop;
      Order_Rows (Pr, Work);
   end Set_Steps;

end Abacus.Qp.Scaling;
