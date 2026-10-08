with AUnit.Assertions; use AUnit.Assertions;

with Abacus;             use Abacus;
with Abacus.Qp;          use Abacus.Qp;
with Abacus.Qp.Admm;     use Abacus.Qp.Admm;
with Abacus_Qp_Fixtures;
with Abacus_Qp_Problems; use Abacus_Qp_Problems;

package body Abacus_Qp_Admm_Tests is

   --  Forming and factoring: ready for a convex P, refused for one with
   --  a negative eigenvalue, out of range for entries that overflow.
   procedure Test_Prepare (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Work   : Workspace (2, 1);
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

   --  The ratio program with its cap at Cap budgets.
   function Ratio_Capped (Cap : Positive) return Problem is
      Pr : Problem := Abacus_Qp_Fixtures.Load ("ratio");
   begin
      for R in 4 .. Pr.K loop
         Pr.E (R, Pr.N) := -(Val (Cap) * One);
      end loop;
      return Pr;
   end Ratio_Capped;

   --  The ratio program with its cap at forty budgets: the scale's
   --  column holds -40 in each of 150 rows, so E'E's entry for it is
   --  240,000, past the values before any step multiplies it.  One step
   --  for every row cannot form the matrix; equilibrated, it is formed.
   --  At 640 budgets the entry is 61 million, and no step a row of the
   --  scale's could take brings the problem's own matrix inside the
   --  values: the matrix factored is the equilibrated one, whose entries
   --  are near one whatever the problem's scale.
   procedure Test_Prepare_Stepped (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Forty  : constant := 40;
      Far    : constant := 640;
      Steps  : constant Settings :=
        (Default_Settings with delta Equilibrate => 10);
      Pr     : Problem := Ratio_Capped (Forty);
      Work   : Workspace (Pr.N, Pr.K);
      Result : Prepare_Result;
   begin
      Prepare (Pr, (Steps with delta Equilibrate => 0), Work, Result);
      Assert (Result = Out_Of_Range, "one step");
      Prepare (Pr, Steps, Work, Result);
      Assert (Result = Ready, "equilibrated");
      Pr := Ratio_Capped (Far);
      Prepare (Pr, Steps, Work, Result);
      Assert (Result = Ready, "equilibrated, at 640");
   end Test_Prepare_Stepped;

   --  Iterations bring the residuals down; a check reads them.
   procedure Test_Iterate (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Pr     : constant Problem := Two (Hi => One);
      Work   : Workspace (2, 1);
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

   --  A check that finds the iterate moving says it is near enough to
   --  polish when its residuals are within Polish_Below and the polish
   --  is due; never when Polish_Every is zero.
   procedure Test_Near (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Pr     : constant Problem := Two (Hi => One);
      Work   : Workspace (2, 1);
      Result : Prepare_Result;
      St     : State := Cold (2, 1);
      Last   : State := St;
      Ok     : Boolean;
      V      : Verdict;
      Loose  : constant Settings :=
        (Default_Settings with delta Polish_Every => 5, Polish_Below => One);
   begin
      Prepare (Pr, Default_Settings, Work, Result);
      for K in 1 .. 5 loop
         Iterate (Pr, Default_Settings, Work, St, Ok);
      end loop;
      Check (Pr, Loose, St, Last, V);
      Assert (V = Near and then Last = St, "near, and kept");
      Last := Cold (2, 1);
      Check (Pr, (Loose with delta Polish_Every => 0), St, Last, V);
      Assert (V = Moving, "no polish asked for");
      Last := Cold (2, 1);
      Check (Pr, (Loose with delta Polish_Every => 3), St, Last, V);
      Assert (V = Moving, "not due");
      Last := Cold (2, 1);
      Check (Pr, (Loose with delta Polish_Below => 0), St, Last, V);
      Assert (V = Moving, "not near");
   end Test_Near;

   overriding
   procedure Register_Tests (T : in out Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T, Test_Prepare_Stepped'Access, "A column too long for one step");
      Register_Routine (T, Test_Prepare'Access, "Prepare");
      Register_Routine (T, Test_Iterate'Access, "Iterate and check");
      Register_Routine (T, Test_Near'Access, "Near enough to polish");
   end Register_Tests;

   overriding
   function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("Abacus.Qp.Admm");
   end Name;

end Abacus_Qp_Admm_Tests;
