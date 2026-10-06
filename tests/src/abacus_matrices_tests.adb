with AUnit.Assertions; use AUnit.Assertions;

with Abacus;          use Abacus;
with Abacus.Matrices; use Abacus.Matrices;

package body Abacus_Matrices_Tests is

   M : constant Matrix (1 .. 2, 1 .. 3) :=
     [[One, 2 * One, 3 * One], [-One, 0, One / 2]];

   --  A times x, rounded once per entry.
   procedure Test_Multiply (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Y  : Vector (1 .. 2);
      Ok : Boolean;
   begin
      Multiply (M, [One, One, 2 * One], Y, Ok);
      Assert (Ok and then Y = [9 * One, 0], "A x");
      Multiply (M, [Val'Last, Val'Last, 0], Y, Ok);
      Assert (not Ok, "a product past the values");
   end Test_Multiply;

   --  X'X, symmetric, from the columns.
   procedure Test_Gram (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      G  : Matrix (1 .. 3, 1 .. 3);
      Ok : Boolean;
   begin
      Gram (M, G, Ok);
      Assert (Ok, "the Gram matrix");
      Assert (G (1, 1) = 2 * One and then G (1, 2) = 2 * One, "row 1");
      Assert (G (2, 3) = 6 * One and then G (3, 2) = 6 * One, "mirrored");
      Assert (G (3, 3) = 9 * One + One / 4, "a square");
   end Test_Gram;

   --  The exact kernels: rows, a row with a vector, columns.
   procedure Test_Kernels (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Assert (Row_Dot (M, 1, 2, 1, 3) = Wide (One) * One / 2, "rows 1 and 2");
      Assert (Row_Dot (M, 1, 2, 2, 1) = 0, "an empty span");
      Assert
        (Row_Vector_Dot (M, 1, [One, One, One], 1, 2) = 3 * Wide (One) * One,
         "a row and a vector");
      Assert (Column_Dot (M, 1, 3) = 5 * Wide (One) * One / 2, "two columns");
      Assert
        (Column_Vector_Dot (M, 2, [One, One]) = 2 * Wide (One) * One,
         "a column and a vector");
   end Test_Kernels;

   procedure Test_Mirror (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      A : Matrix (1 .. 2, 1 .. 2) := [[1, 0], [5, 2]];
   begin
      Mirror (A);
      Assert (A = [[1, 5], [5, 2]], "the upper from the lower");
   end Test_Mirror;

   overriding
   procedure Register_Tests (T : in out Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine (T, Test_Multiply'Access, "A x");
      Register_Routine (T, Test_Gram'Access, "X'X");
      Register_Routine (T, Test_Kernels'Access, "The exact kernels");
      Register_Routine (T, Test_Mirror'Access, "Mirror");
   end Register_Tests;

   overriding
   function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("Abacus.Matrices");
   end Name;

end Abacus_Matrices_Tests;
