with AUnit.Assertions; use AUnit.Assertions;
with Spike;            use Spike;
with Spike.Admm;

package body Spike_Admm_Tests is

   package A40 is new Spike.Admm (40);
   use A40;

   One : constant := 2**40;

   Defaults : constant Settings :=
     (Rho_Shift   => 0,
      Row_Shift   => 10,
      Sigma_Shift => -20,
      Alpha       => One * 8 / 5,
      Max_Iter    => 1_000,
      Check_Every => 10,
      Tol_Primal  => 2**10,
      Tol_Dual    => 2**12);

   --  A budget is split between two equal assets: minimize (1/2) x'x with
   --  both in 0 .. 1 and summing to exactly 1; each is a half.
   procedure Test_Two_Equal (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Pr     : constant Problem :=
        (N      => 2,
         K      => 1,
         P      => [[One, 0], [0, One]],
         Q      => [0, 0],
         Lo     => [0, 0],
         Hi     => [One, One],
         E      => [[One, One]],
         Row_Lo => [One],
         Row_Hi => [One]);
      St     : State := Cold (2, 1);
      Result : Result_Kind;
   begin
      Solve (Pr, Defaults, St, Result);
      Assert (Result = Converged, "converged: " & Result'Image);
      Assert
        (abs (St.X (1) - One / 2) <= 2**10
         and then abs (St.X (2) - One / 2) <= 2**10,
         "each is a half");
      Assert (St.Iterations <= Defaults.Max_Iter, "within the cap");
   end Test_Two_Equal;

   --  A bound that binds: the cheaper asset is held at its cap of 0.75.
   procedure Test_Bound_Binds (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Pr     : constant Problem :=
        (N      => 2,
         K      => 1,
         P      => [[One, 0], [0, One]],
         Q      => [-One, 0],
         Lo     => [0, 0],
         Hi     => [One * 3 / 4, One],
         E      => [[One, One]],
         Row_Lo => [One],
         Row_Hi => [One]);
      St     : State := Cold (2, 1);
      Result : Result_Kind;
   begin
      Solve (Pr, Defaults, St, Result);
      Assert (Result = Converged, "converged: " & Result'Image);
      Assert (abs (St.X (1) - One * 3 / 4) <= 2**10, "held at its cap");
      Assert (abs (St.X (2) - One / 4) <= 2**10, "the rest");
   end Test_Bound_Binds;

   overriding
   procedure Register_Tests (T : in out Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T, Test_Two_Equal'Access, "Two equal assets split the budget");
      Register_Routine (T, Test_Bound_Binds'Access, "A bound binds");
   end Register_Tests;

   overriding
   function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("Spike.Admm");
   end Name;

end Spike_Admm_Tests;
