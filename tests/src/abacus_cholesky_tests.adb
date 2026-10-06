with AUnit.Assertions; use AUnit.Assertions;

with Abacus;          use Abacus;
with Abacus.Cholesky; use Abacus.Cholesky;

package body Abacus_Cholesky_Tests is

   --  [[4, 2], [2, 3]] = L L' with L = [[2, 0], [1, sqrt 2]].
   procedure Test_Factor (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      A       : Matrix (1 .. 2, 1 .. 2) := [[4 * One, 0], [2 * One, 3 * One]];
      D       : Pivots (1 .. 2);
      Outcome : Factor_Outcome;
      Root_2  : constant := 1_554_944_255_988;
   begin
      Factor (A, D, 1, Outcome);
      Assert (Outcome = (Factored, 0), "factored");
      Assert (D = [2 * One, Root_2], "the pivots");
      Assert (A (2, 1) = One and then A (1, 2) = One, "L, mirrored");
   end Test_Factor;

   --  L L' x = b, by the forward and the back solve.
   procedure Test_Solve (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      A       : Matrix (1 .. 2, 1 .. 2) := [[4 * One, 0], [2 * One, 3 * One]];
      D       : Pivots (1 .. 2);
      Outcome : Factor_Outcome;
      B       : Vector (1 .. 2) := [8 * One, 7 * One];
      Result  : Solve_Result;
   begin
      Factor (A, D, 1, Outcome);
      Solve (A, D, B, Result);
      Assert (Result = Solved, "solved");
      Assert
        (abs (B (1) - 5 * One / 4) <= 2
         and then abs (B (2) - 3 * One / 2) <= 2,
         "x = (1.25, 1.5)");
   end Test_Solve;

   --  The leading block alone: factored and solved as a matrix of its
   --  own, whatever lies past it, which is left as it was.
   procedure Test_Leading (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      A       : Matrix (1 .. 3, 1 .. 3) :=
        [[4 * One, 0, 0], [2 * One, 3 * One, 0], [One, One, -One]];
      D       : Pivots (1 .. 3);
      Outcome : Factor_Outcome;
      B       : Vector (1 .. 3) := [8 * One, 7 * One, 9 * One];
      Result  : Solve_Result;
   begin
      Factor_Leading (A, D, 2, 1, Outcome);
      Assert (Outcome = (Factored, 0), "the block factored");
      Assert (A (3, 3) = -One and then A (1, 3) = 0, "past it, untouched");
      Solve_Leading (A, D, B, 2, Result);
      Assert (Result = Solved, "solved");
      Assert
        (abs (B (1) - 5 * One / 4) <= 2
         and then abs (B (2) - 3 * One / 2) <= 2,
         "x = (1.25, 1.5)");
      Assert (B (3) = 9 * One, "past the block, untouched");
      Factor_Leading (A, D, 3, 1, Outcome);
      Assert (Outcome.Column = 3, "the whole is refused at its third column");
   end Test_Leading;

   --  A pivot under the floor, or a negative one, names its column.
   procedure Test_Refused (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Thousandth : constant := One / 1_000;
      A          : Matrix (1 .. 3, 1 .. 3) :=
        [[One, 0, 0], [One, One, 0], [One, One, One]];
      D          : Pivots (1 .. 3);
      Outcome    : Factor_Outcome;
   begin
      Factor (A, D, Thousandth, Outcome);
      Assert (Outcome = (Not_Positive_Definite, 2), "singular at column 2");
      A := [[One, 0, 0], [0, -One, 0], [0, 0, One]];
      Factor (A, D, 1, Outcome);
      Assert (Outcome = (Not_Positive_Definite, 2), "negative at column 2");
   end Test_Refused;

   --  Least squares with a ridge: y = 1 + 2 x exactly.
   procedure Test_Least_Squares (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      X       : constant Matrix (1 .. 4, 1 .. 2) :=
        [[One, 0], [One, One], [One, 2 * One], [One, 3 * One]];
      Y       : constant Vector (1 .. 4) := [One, 3 * One, 5 * One, 7 * One];
      Beta    : Vector (1 .. 2);
      Outcome : Factor_Outcome;
   begin
      Least_Squares (X, Y, 0, Beta, Outcome);
      Assert (Outcome = (Factored, 0), "fitted");
      Assert
        (abs (Beta (1) - One) <= 4 and then abs (Beta (2) - 2 * One) <= 4,
         "intercept 1, slope 2");
   end Test_Least_Squares;

   overriding
   procedure Register_Tests (T : in out Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine (T, Test_Factor'Access, "A = L L'");
      Register_Routine (T, Test_Solve'Access, "Two triangular solves");
      Register_Routine (T, Test_Refused'Access, "Refused at its column");
      Register_Routine (T, Test_Leading'Access, "A leading block alone");
      Register_Routine (T, Test_Least_Squares'Access, "Least squares");
   end Register_Tests;

   overriding
   function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("Abacus.Cholesky");
   end Name;

end Abacus_Cholesky_Tests;
