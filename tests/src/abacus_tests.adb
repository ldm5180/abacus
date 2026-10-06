with AUnit.Assertions; use AUnit.Assertions;

with Abacus; use Abacus;

package body Abacus_Tests is

   --  One is 2**40 units, and the grid's step is one unit.
   procedure Test_One (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Assert (Raw'Value ("1099511627776") = One, "one is 2**40 units");
   end Test_One;

   overriding
   procedure Register_Tests (T : in out Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine (T, Test_One'Access, "One is 2**40 units");
   end Register_Tests;

   overriding
   function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("Abacus");
   end Name;

end Abacus_Tests;
