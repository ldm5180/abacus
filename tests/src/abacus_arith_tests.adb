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

   --  A product or a quotient past the values is held at the largest
   --  value of its sign and reported; a quotient by zero is undefined.
   procedure Test_Saturates (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Big : constant Val := 100_000 * One;
   begin
      Assert (Mul_Sat (Big, Big) = (Val'Last, Saturated), "too large");
      Assert (Mul_Sat (Big, -Big) = (Val'First, Saturated), "too small");
      Assert (Mul_Sat (One / 2, One / 2) = (One / 4, Ok), "in range");
      Assert (Div_Sat (Big, 1) = (Val'Last, Saturated), "a huge quotient");
      Assert (Div_Sat (-Big, 1) = (Val'First, Saturated), "a huge negative");
      Assert (Div_Sat (One, 2 * One) = (One / 2, Ok), "a half");
      Assert (Div_Sat (One, 0) = (0, Undefined), "a quotient by zero");
   end Test_Saturates;

   --  A wide result that fits is stored; one that does not clears Ok and
   --  leaves the target alone.
   procedure Test_Store (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      V  : Val := 7;
      Ok : Boolean := True;
   begin
      Store (Wide (Val'Last), V, Ok);
      Assert (V = Val'Last and then Ok, "the largest value fits");
      Store (Wide (Val'Last) + 1, V, Ok);
      Assert (V = Val'Last and then not Ok, "one more does not");
      Store (-5, V, Ok);
      Assert (V = -5 and then not Ok, "a later fit stores but keeps Ok");
   end Test_Store;

   overriding
   procedure Register_Tests (T : in out Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T, Test_Half_Times_Half'Access, "A half times a half is a quarter");
      Register_Routine
        (T, Test_Ties_Away'Access, "A tie rounds away from zero");
      Register_Routine (T, Test_Third'Access, "A quotient rounds to nearest");
      Register_Routine
        (T, Test_Saturates'Access, "A result too large is held and said");
      Register_Routine (T, Test_Store'Access, "The checked store");
   end Register_Tests;

   overriding
   function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("Abacus.Arith");
   end Name;

end Abacus_Arith_Tests;
