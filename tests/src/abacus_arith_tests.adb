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

   --  V times 2**S: exact for S at or above zero, rounded half away from
   --  zero below it, at both ends of the exponents.
   procedure Test_Scaled (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Assert (Power_Of (0) = 1, "2**0");
      Assert (Power_Of (Widest_Exponent) = 2**30, "2**30");
      Assert (Scaled (3, 0) = 3, "times one");
      Assert (Scaled (-3, 2) = -12, "times four");
      Assert
        (Scaled (Val'Last, Widest_Exponent) = Scaled_Bound,
         "the largest magnitude");
      Assert
        (Scaled (Val'First, Widest_Exponent) = -Scaled_Bound,
         "the largest negative magnitude");
      Assert (Scaled (6, -2) = 2, "1.5 rounds up to 2");
      Assert (Scaled (-6, -2) = -2, "-1.5 rounds down to -2");
      Assert (Scaled (5, -2) = 1, "1.25 rounds to 1");
      Assert (Scaled (Val'Last, -Widest_Exponent) = 2**27, "a long shift");
   end Test_Scaled;

   --  A wide value times a power of two: exact upward, rounded once to
   --  nearest downward (to within a unit past a shift of 30), and held
   --  to Held_Bound either way.
   procedure Test_Times_Power (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Big     : constant Wide := 2**100;
      Far     : constant := 200;
      Farther : constant := 300;
   begin
      Assert (Times_Power (3, 0) = 3, "times one");
      Assert (Times_Power (-3, 40) = -3 * 2**40, "a long shift up");
      Assert (Times_Power (6, -2) = 2, "1.5 rounds up to 2");
      Assert (Times_Power (-5, -2) = -1, "-1.25 rounds to -1");
      Assert (Times_Power (Big, -70) = 2**30, "down in three steps");
      Assert (Times_Power (Big + 2**69, -70) = 2**30 + 1, "a half: up");
      Assert (Times_Power (1, -Far) = 0, "past every place");
      Assert (Times_Power (Big, 30) = Held_Bound, "held");
      Assert (Times_Power (-1, Farther) = -Held_Bound, "held, negative");
   end Test_Times_Power;

   overriding
   procedure Register_Tests (T : in out Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T, Test_Times_Power'Access, "A wide value times a power of two");
      Register_Routine
        (T, Test_Half_Times_Half'Access, "A half times a half is a quarter");
      Register_Routine
        (T, Test_Ties_Away'Access, "A tie rounds away from zero");
      Register_Routine (T, Test_Third'Access, "A quotient rounds to nearest");
      Register_Routine
        (T, Test_Saturates'Access, "A result too large is held and said");
      Register_Routine (T, Test_Store'Access, "The checked store");
      Register_Routine (T, Test_Scaled'Access, "A value times a power of two");
   end Register_Tests;

   overriding
   function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("Abacus.Arith");
   end Name;

end Abacus_Arith_Tests;
