with AUnit.Assertions; use AUnit.Assertions;
with Spike;            use Spike;
with Spike.Linear;

package body Spike_Linear_Tests is

   package L40 is new Spike.Linear (40);
   use L40;

   One : constant := 2**40;

   --  A = L L' with L = [2 0 0; 1 3 0; -1 1 2]: every step is exact on
   --  the grid, so the factor is too, and the upper triangle mirrors it.
   procedure Test_Factor_Exact (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      A       : Matrix (1 .. 3, 1 .. 3) :=
        [[4 * One, 2 * One, -2 * One],
         [2 * One, 10 * One, 2 * One],
         [-2 * One, 2 * One, 6 * One]];
      D       : Pivots (1 .. 3);
      Outcome : Factor_Outcome;
   begin
      Factor (A, D, 1, Outcome);
      Assert (Outcome = (Factored, 0), "factored");
      Assert (D = [2 * One, 3 * One, 2 * One], "the pivots");
      Assert
        (A (2, 1) = One and then A (3, 1) = -One and then A (3, 2) = One,
         "the lower triangle");
      Assert
        (A (1, 2) = One and then A (1, 3) = -One and then A (2, 3) = One,
         "the mirror");
   end Test_Factor_Exact;

   --  A repeated column leaves no pivot, and the column is named.
   procedure Test_Factor_Refuses (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      A       : Matrix (1 .. 3, 1 .. 3) :=
        [[One, 0, One], [0, One, 0], [One, 0, One]];
      D       : Pivots (1 .. 3);
      Outcome : Factor_Outcome;
   begin
      Factor (A, D, 2**20, Outcome);
      Assert (Outcome = (Not_Positive_Definite, 3), "column 3 refused");
   end Test_Factor_Refuses;

   --  With the exact factor above, A x = b is solved exactly in place.
   procedure Test_Solve_Exact (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      A       : Matrix (1 .. 3, 1 .. 3) :=
        [[4 * One, 2 * One, -2 * One],
         [2 * One, 10 * One, 2 * One],
         [-2 * One, 2 * One, 6 * One]];
      D       : Pivots (1 .. 3);
      Outcome : Factor_Outcome;
      B       : Vector (1 .. 3) := [-2 * One, -4 * One, 8 * One];
      Result  : Solve_Result;
   begin
      Factor (A, D, 1, Outcome);
      Solve (A, D, B, Result);
      Assert (Result = Solved, "solved");
      Assert (B = [One, -One, 2 * One], "x = [1, -1, 2]");
   end Test_Solve_Exact;

   --  A quotient past the value bound is refused, not wrapped.
   procedure Test_Solve_Refuses (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      L      : constant Matrix (1 .. 1, 1 .. 1) := [[1]];
      D      : constant Pivots (1 .. 1) := [1];
      B      : Vector (1 .. 1) := [2**56];
      Result : Solve_Result;
   begin
      Solve (L, D, B, Result);
      Assert (Result = Out_Of_Range, "out of range");
   end Test_Solve_Refuses;

   overriding
   procedure Register_Tests (T : in out Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine (T, Test_Factor_Exact'Access, "Factor an exact matrix");
      Register_Routine
        (T, Test_Factor_Refuses'Access, "Factor refuses a repeated column");
      Register_Routine (T, Test_Solve_Exact'Access, "Solve exactly");
      Register_Routine
        (T, Test_Solve_Refuses'Access, "Solve refuses out of range");
   end Register_Tests;

   overriding
   function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("Spike.Linear");
   end Name;

end Spike_Linear_Tests;
