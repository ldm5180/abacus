with AUnit.Assertions; use AUnit.Assertions;

with Abacus;              use Abacus;
with Abacus.Qp;           use Abacus.Qp;
with Abacus.Qp.Admm;
with Abacus.Qp.Certificate;
with Abacus.Qp.Crossover; use Abacus.Qp.Crossover;
with Abacus_Qp_Fixtures;
with Abacus_Qp_Problems;  use Abacus_Qp_Problems;

package body Abacus_Qp_Crossover_Tests is

   --  Maximize x1 + 2 x2 with x in [0, 1] and x1 + x2 at most 1.5: the
   --  vertex (0.5, 1).
   function Linear return Problem
   is (With_P
         (Two
            (Q      => [-One, -2 * One],
             Hi     => One,
             Row_Lo => No_Lower,
             Row_Hi => 3 * One / 2),
          [[0, 0], [0, 0]]));

   --  Work prepared for Pr.
   procedure Prepared (Pr : Problem; Work : out Workspace) is
      Result : Admm.Prepare_Result;
   begin
      Admm.Prepare (Pr, Default_Settings, Work, Result);
   end Prepared;

   --  From a cold iterate, which holds nothing, the crossover makes a
   --  basis and pivots to the vertex, and the answer is certified.
   procedure Test_From_Cold (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Pr     : constant Problem := Linear;
      Work   : Workspace (2, 1);
      St     : State := Cold (2, 1);
      Passed : Boolean;
   begin
      Prepared (Pr, Work);
      Run (Pr, Default_Settings, Work, St, Passed);
      Assert (Passed, "certified");
      Assert (abs (St.X (1) - One / 2) <= 16, "x1" & St.X (1)'Image);
      Assert (abs (St.X (2) - One) <= 16, "x2" & St.X (2)'Image);
      Assert
        (Certificate.Certified (Pr, St, Default_Settings.Tol),
         "its certificate");
   end Test_From_Cold;

   --  The pinned program from a hundred iterations: its budgets each pin
   --  one column, and an equality row may depend on the inequality rows
   --  held before it.  The basis keeps the equalities and lets an
   --  inequality go, and the walk reaches the degenerate vertex.
   procedure Test_Pinned (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Iters  : constant := 100;
      Pr     : constant Problem := Abacus_Qp_Fixtures.Load ("pinned");
      Work   : Workspace (Pr.N, Pr.K);
      St     : State := Cold (Pr.N, Pr.K);
      Ok     : Boolean := True;
      Passed : Boolean;
   begin
      Prepared (Pr, Work);
      for K in 1 .. Iters loop
         Admm.Iterate (Pr, Default_Settings, Work, St, Ok);
      end loop;
      Assert (Ok, "iterated");
      Run (Pr, Default_Settings, Work, St, Passed);
      Assert (Passed, "certified");
   end Test_Pinned;

   --  A problem with a quadratic term has no vertex to cross over to: it
   --  is left as it was.
   procedure Test_Not_Linear (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Pr     : constant Problem := Two (Hi => One);
      Work   : Workspace (2, 1);
      St     : State := Cold (2, 1);
      Passed : Boolean;
   begin
      Assert (not Is_Linear (Pr), "a quadratic term");
      Prepared (Pr, Work);
      Run (Pr, Default_Settings, Work, St, Passed);
      Assert (not Passed and then St = Cold (2, 1), "left as it was");
   end Test_Not_Linear;

   overriding
   procedure Register_Tests (T : in out Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine (T, Test_From_Cold'Access, "A vertex, from cold");
      Register_Routine (T, Test_Not_Linear'Access, "No crossover for a QP");
      Register_Routine (T, Test_Pinned'Access, "Equalities kept in a basis");
   end Register_Tests;

   overriding
   function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("Abacus.Qp.Crossover");
   end Name;

end Abacus_Qp_Crossover_Tests;
