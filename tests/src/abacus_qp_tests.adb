with AUnit.Assertions; use AUnit.Assertions;

with Abacus;    use Abacus;
with Abacus.Qp; use Abacus.Qp;

package body Abacus_Qp_Tests is

   --  A cold start is zeros, and fits the problem it was made for.
   procedure Test_Cold (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      St : constant State := Cold (3, 1);
      Pr : constant Problem :=
        (N      => 3,
         K      => 1,
         P      => [others => [others => 0]],
         Q      => [others => 0],
         Lo     => [others => 0],
         Hi     => [others => One],
         E      => [others => [others => One]],
         Row_Lo => [One],
         Row_Hi => [One]);
   begin
      Assert (St.X = [0, 0, 0] and then St.Y_Row = [0], "zeros");
      Assert (St.Iterations = 0, "no iterations");
      Assert (Fits_State (Pr, St), "fits its problem");
      Assert (not Fits_State (Pr, Cold (3, 0)), "not another's");
   end Test_Cold;

   --  The defaults are S0's.
   procedure Test_Defaults (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Ten_Billionth : constant := One / 10_000_000_000;
   begin
      Assert (Default_Settings.Row_Shift = 3, "rho_row 2**3");
      Assert (Default_Settings.Sigma_Shift = -20, "sigma 2**-20");
      Assert (Default_Settings.Tol.Primal = Ten_Billionth, "1e-10");
   end Test_Defaults;

   overriding
   procedure Register_Tests (T : in out Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine (T, Test_Cold'Access, "A cold start");
      Register_Routine (T, Test_Defaults'Access, "The default settings");
   end Register_Tests;

   overriding
   function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("Abacus.Qp");
   end Name;

end Abacus_Qp_Tests;
