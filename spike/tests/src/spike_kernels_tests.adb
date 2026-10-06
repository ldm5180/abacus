with AUnit.Assertions; use AUnit.Assertions;
with Spike;            use Spike;
with Spike.Kernels;    use Spike.Kernels;

package body Spike_Kernels_Tests is

   --  Two rows dotted over a column range are the exact sum of products;
   --  an empty range is zero.
   procedure Test_Dot_Rows (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      M : constant Matrix (1 .. 2, 1 .. 3) := [[1, 2, 3], [4, -5, 6]];
   begin
      Assert (Dot (M, 1, 2, 1, 3) = 4 - 10 + 18, "whole rows");
      Assert (Dot (M, 1, 2, 2, 3) = -10 + 18, "a suffix");
      Assert (Dot (M, 2, 2, 1, 2) = 16 + 25, "a row with itself");
      Assert (Dot (M, 1, 2, 3, 2) = 0, "an empty range");
   end Test_Dot_Rows;

   --  A row dotted with a vector, and the widest sum the bounds allow:
   --  Max_N products of the largest values, exactly.
   procedure Test_Dot_Vector (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      M   : constant Matrix (1 .. 1, 1 .. 3) := [[1, 2, 3]];
      V   : constant Vector (1 .. 3) := [7, 8, 9];
      Big : constant Matrix (1 .. 1, 1 .. Max_N) :=
        [others => [others => Val'Last]];
      Top : constant Vector (1 .. Max_N) := [others => Val'Last];
   begin
      Assert (Dot (M, 1, V, 1, 3) = 7 + 16 + 27, "row times vector");
      Assert (Dot (M, 1, V, 2, 2) = 16, "one element");
      Assert
        (Dot (Big, 1, Top, 1, Max_N) = Wide (Max_N) * 2**114,
         "the widest sum");
   end Test_Dot_Vector;

   --  The square root of a wide value is the nearest integer: exact on
   --  squares, half way rounds up, and the largest argument fits a value.
   procedure Test_Root (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Assert (Root (0) = 0, "zero");
      Assert (Root (1) = 1, "one");
      Assert (Root (2) = 1, "two rounds down");
      Assert (Root (3) = 2, "three rounds up");
      Assert (Root (4 * 2**80) = 2 * 2**40, "four at Frac 40");
      Assert (Root (12) = 3, "12 is under 3.5 squared");
      Assert (Root (13) = 4, "13 is over 3.5 squared");
      Assert (Root (Term_Bound - 1) = 2**57, "the largest argument");
   end Test_Root;

   --  A quotient rounds half away from zero.
   procedure Test_Div_Round (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Assert (Div_Round (7, 2) = 4, "3.5 rounds up");
      Assert (Div_Round (-7, 2) = -4, "-3.5 rounds down");
      Assert (Div_Round (5, 3) = 2, "1.67 is 2");
      Assert (Div_Round (-4, 3) = -1, "-1.33 is -1");
   end Test_Div_Round;

   overriding
   procedure Register_Tests (T : in out Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine (T, Test_Dot_Rows'Access, "Dot of two rows");
      Register_Routine
        (T, Test_Dot_Vector'Access, "Dot of a row and a vector");
      Register_Routine (T, Test_Root'Access, "Root to nearest");
      Register_Routine (T, Test_Div_Round'Access, "Div_Round half away");
   end Register_Tests;

   overriding
   function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("Spike.Kernels");
   end Name;

end Spike_Kernels_Tests;
