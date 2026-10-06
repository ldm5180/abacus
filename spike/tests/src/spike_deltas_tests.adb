with AUnit.Assertions;  use AUnit.Assertions;
with Spike;             use Spike;
with Spike.Delta_Types; use Spike.Delta_Types;
with Spike.Deltas;

package body Spike_Deltas_Tests is

   package D40 is new Spike.Deltas (Fix_40, Acc_40);
   use D40;

   --  Representation (a) computes what representation (b) does: the same
   --  exact dot product, root, factor and solve as the Linear tests.
   procedure Test_Dot (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      M : constant Fix_Matrix (1 .. 2, 1 .. 3) :=
        [[1.0, 2.0, 3.0], [4.0, -5.0, 6.5]];
   begin
      Assert (Dot (M, 1, 2, 1, 3) = 4.0 - 10.0 + 19.5, "whole rows");
      Assert (Dot (M, 1, 2, 3, 2) = 0.0, "an empty range");
   end Test_Dot;

   procedure Test_Root (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Assert (Root (4.0) = 2.0, "four");
      Assert (Root (2.25) = 1.5, "2.25");
      Assert
        (Root (Acc_40'Small * 3) = Fix_40'Small * 2,
         "three units of the accumulator round up");
   end Test_Root;

   procedure Test_Factor_Solve (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      A       : Fix_Matrix (1 .. 3, 1 .. 3) :=
        [[4.0, 2.0, -2.0], [2.0, 10.0, 2.0], [-2.0, 2.0, 6.0]];
      D       : D40.Pivots (1 .. 3);
      B       : Fix_Vector (1 .. 3) := [-2.0, -4.0, 8.0];
      Outcome : Outcome_Kind;
   begin
      Factor (A, D, Fix_40'Small, Outcome);
      Assert (Outcome = Done, "factored");
      Assert (D = [2.0, 3.0, 2.0], "the pivots");
      Assert (A (3, 1) = -1.0 and then A (1, 3) = -1.0, "lower and mirror");
      Solve (A, D, B, Outcome);
      Assert (Outcome = Done, "solved");
      Assert (B = [1.0, -1.0, 2.0], "x = [1, -1, 2]");
   end Test_Factor_Solve;

   procedure Test_Factor_Refuses (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      A       : Fix_Matrix (1 .. 2, 1 .. 2) := [[1.0, 1.0], [1.0, 1.0]];
      D       : D40.Pivots (1 .. 2);
      Outcome : Outcome_Kind;
   begin
      Factor (A, D, 0.0009765625, Outcome);
      Assert (Outcome = Not_Positive_Definite, "refused");
   end Test_Factor_Refuses;

   overriding
   procedure Register_Tests (T : in out Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine (T, Test_Dot'Access, "Dot");
      Register_Routine (T, Test_Root'Access, "Root");
      Register_Routine (T, Test_Factor_Solve'Access, "Factor and solve");
      Register_Routine (T, Test_Factor_Refuses'Access, "Factor refuses");
   end Register_Tests;

   overriding
   function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("Spike.Deltas");
   end Name;

end Spike_Deltas_Tests;
