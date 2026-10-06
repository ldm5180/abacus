with AUnit.Assertions; use AUnit.Assertions;

with Abacus;             use Abacus;
with Abacus.Qp;          use Abacus.Qp;
with Abacus.Qp.Admm;     use Abacus.Qp.Admm;
with Abacus_Qp_Problems; use Abacus_Qp_Problems;

package body Abacus_Qp_Admm_Tests is

   --  Forming and factoring: ready for a convex P, refused for one with
   --  a negative eigenvalue, out of range for entries that overflow.
   procedure Test_Prepare (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Work   : Workspace (2);
      Result : Prepare_Result;
   begin
      Prepare (Two (Hi => One), Default_Settings, Work, Result);
      Assert (Result = Ready, "ready");
      Prepare (With_P (Two, [[0, 0], [0, 0]]), Default_Settings, Work, Result);
      Assert (Result = Ready, "a linear program is convex");
      Prepare
        (With_P (Two, [[One, 2 * One], [2 * One, One]]),
         Default_Settings,
         Work,
         Result);
      Assert (Result = Not_Convex, "eigenvalues 3 and -1");
      Prepare
        (With_P (Two, [[Val'Last, 0], [0, One]]),
         Default_Settings,
         Work,
         Result);
      Assert (Result = Out_Of_Range, "a diagonal past the values");
   end Test_Prepare;

   --  Iterations bring the residuals down; a check reads them.
   procedure Test_Iterate (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Pr     : constant Problem := Two (Hi => One);
      Work   : Workspace (2);
      Result : Prepare_Result;
      St     : State := Cold (2, 1);
      Last   : State := St;
      Ok     : Boolean;
      V      : Verdict;
      First  : Residual;
   begin
      Prepare (Pr, Default_Settings, Work, Result);
      Iterate (Pr, Default_Settings, Work, St, Ok);
      Assert (Ok and then St.Iterations = 1, "one iteration");
      First := Residuals (Pr, St);
      for K in 1 .. 50 loop
         Iterate (Pr, Default_Settings, Work, St, Ok);
      end loop;
      Assert (Residuals (Pr, St).Primal < First.Primal, "primal falls");
      Check (Pr, Default_Settings, St, Last, V);
      Assert (V in Converged | Moving, "a verdict");
      Assert (V = Converged or else Last = St, "a moving state is kept");
      Last := St;
      Check (Pr, Default_Settings, St, Last, V);
      Assert (V in Converged | Held, "the same state twice");
   end Test_Iterate;

   overriding
   procedure Register_Tests (T : in out Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine (T, Test_Prepare'Access, "Prepare");
      Register_Routine (T, Test_Iterate'Access, "Iterate and check");
   end Register_Tests;

   overriding
   function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("Abacus.Qp.Admm");
   end Name;

end Abacus_Qp_Admm_Tests;
