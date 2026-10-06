with AUnit.Assertions; use AUnit.Assertions;

with Abacus;                use Abacus;
with Abacus.Qp;             use Abacus.Qp;
with Abacus.Qp.Certificate; use Abacus.Qp.Certificate;
with Abacus_Qp_Problems;    use Abacus_Qp_Problems;

package body Abacus_Qp_Certificate_Tests is

   Half : constant Val := One / 2;

   --  The exact answer of the split, with its multipliers: x = (1/2,
   --  1/2), the row's dual -1/2 (its lower bound holds), the box's zero.
   function Answer return State
   is ((N          => 2,
        K          => 1,
        X | Z      => [Half, Half],
        Y          => [0, 0],
        Z_Row      => [One],
        Y_Row      => [-Half],
        Iterations => 0));

   procedure Test_Residuals (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Pr : constant Problem := Two (Hi => One);
      St : State := Answer;
   begin
      Assert (Primal_Residual (Pr, St) = 0, "no primal residual");
      Assert (Dual_Residual (Pr, St) = 0, "no dual residual");
      Assert (Complementarity (Pr, St) = 0, "no gap");
      Assert (Certified (Pr, St, (0, 0, 0)), "certified to zero");
      St.X (1) := One + 7;
      Assert
        (Primal_Residual (Pr, St) = Wide (Half + 7),
         "past the row and the box");
      St := Answer;
      St.Y (1) := 5;
      Assert (Dual_Residual (Pr, St) = 5, "a stray multiplier");
      Assert (Complementarity (Pr, St) = 3, "five units on a slack of a half");
      Assert (not Certified (Pr, St, (0, 4, 4)), "not within four");
   end Test_Residuals;

   --  A multiplier against an open bound counts whole.
   procedure Test_Open (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Pr : Problem := Two (Hi => One);
      St : State := Answer;
   begin
      Pr.Hi (1) := No_Upper;
      St.Y (1) := 9;
      Assert (Complementarity (Pr, St) = 9, "against an open bound");
   end Test_Open;

   --  The duals' change in an infeasible problem is a certificate; a
   --  change too small, or one with an open bound to escape by, is not.
   procedure Test_Infeasible (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Pr   : Problem := Two (Hi => One / 4);
      Last : constant State := Cold (2, 1);
      St   : State := Cold (2, 1);
   begin
      St.Y := [One, One];
      St.Y_Row := [-One];
      Assert (Infeasible (Pr, St, Last, 16), "a certificate");
      St.Y := [1, 1];
      St.Y_Row := [-1];
      Assert (not Infeasible (Pr, St, Last, 16), "noise");
      St.Y := [One, One];
      St.Y_Row := [-One];
      Pr.Hi (2) := No_Upper;
      Assert (not Infeasible (Pr, St, Last, 16), "an open bound");
   end Test_Infeasible;

   --  x's change along an open bound, with the objective falling, is a
   --  certificate of unboundedness; with a bounded variable it is not.
   procedure Test_Unbounded (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Pr   : Problem :=
        With_P
          (Two
             (Q      => [-One, 0],
              Hi     => One,
              Row_Lo => No_Lower,
              Row_Hi => No_Upper),
           [[0, 0], [0, 0]]);
      Last : constant State := Cold (2, 1);
      St   : State := Cold (2, 1);
   begin
      St.X := [One, 0];
      Assert (not Unbounded (Pr, St, Last, 16), "x1 is bounded");
      Pr.Hi (1) := No_Upper;
      Assert (Unbounded (Pr, St, Last, 16), "x1 is not");
      Pr.Q := [One, 0];
      Assert (not Unbounded (Pr, St, Last, 16), "the objective rises");
   end Test_Unbounded;

   overriding
   procedure Register_Tests (T : in out Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine (T, Test_Residuals'Access, "Residuals and the gap");
      Register_Routine (T, Test_Open'Access, "An open bound");
      Register_Routine (T, Test_Infeasible'Access, "Infeasibility");
      Register_Routine (T, Test_Unbounded'Access, "Unboundedness");
   end Register_Tests;

   overriding
   function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("Abacus.Qp.Certificate");
   end Name;

end Abacus_Qp_Certificate_Tests;
