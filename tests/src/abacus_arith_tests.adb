with AUnit.Assertions; use AUnit.Assertions;

with Abacus;       use Abacus;
with Abacus.Arith; use Abacus.Arith;

package body Abacus_Arith_Tests is

   procedure Test_Half_Times_Half (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Assert (Mul (One / 2, One / 2) = One / 4, "a half squared");
   end Test_Half_Times_Half;

   overriding
   procedure Register_Tests (T : in out Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T, Test_Half_Times_Half'Access, "A half times a half is a quarter");
   end Register_Tests;

   overriding
   function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("Abacus.Arith");
   end Name;

end Abacus_Arith_Tests;
