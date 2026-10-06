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

   --  A product halfway between two units rounds away from zero, on both
   --  sides of it; one below halfway rounds toward it.
   procedure Test_Ties_Away (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Assert (Mul (3, One / 2) = 2, "1.5 units up to 2");
      Assert (Mul (-3, One / 2) = -2, "-1.5 units down to -2");
      Assert (Mul (1, One / 2) = 1, "0.5 units up to 1");
      Assert (Mul (-1, One / 2) = -1, "-0.5 units down to -1");
      Assert (Mul (1, One / 4) = 0, "0.25 units to 0");
      Assert (Mul (-1, One / 4) = 0, "-0.25 units to 0");
      Assert (Product_Of (Val'Last, Val'Last) = 2**74, "the largest product");
   end Test_Ties_Away;

   --  A third is the nearest unit to 2**40 / 3, whatever the signs.
   procedure Test_Third (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Third : constant := 366_503_875_925;
   begin
      Assert (Div (One, 3 * One) = Third, "one over three");
      Assert (Div (-One, 3 * One) = -Third, "minus one over three");
      Assert (Div (One, -3 * One) = -Third, "one over minus three");
      Assert (Div (-One, -3 * One) = Third, "minus over minus");
      Assert (Div (2 * One, 3 * One) = 2 * Third + 1, "two thirds round up");
      Assert (Div (1, 2 * One) = 1, "half a unit rounds away");
      Assert (Div (-1, 2 * One) = -1, "minus half a unit rounds away");
   end Test_Third;

   overriding
   procedure Register_Tests (T : in out Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T, Test_Half_Times_Half'Access, "A half times a half is a quarter");
      Register_Routine
        (T, Test_Ties_Away'Access, "A tie rounds away from zero");
      Register_Routine (T, Test_Third'Access, "A quotient rounds to nearest");
   end Register_Tests;

   overriding
   function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("Abacus.Arith");
   end Name;

end Abacus_Arith_Tests;
