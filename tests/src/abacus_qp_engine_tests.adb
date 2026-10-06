with AUnit.Assertions; use AUnit.Assertions;

with Abacus;             use Abacus;
with Abacus.Qp;          use Abacus.Qp;
with Abacus.Qp.Certificate;
with Abacus_Qp_Fixtures;
with Abacus_Qp_Problems; use Abacus_Qp_Problems;

package body Abacus_Qp_Engine_Tests is

   --  A billionth, the tolerance the answers here are read to.
   Billionth : constant := One / 1_000_000_000;

   procedure Near (Got, Want : Val; What : String) is
   begin
      Assert (abs (Got - Want) <= Billionth, What & Got'Image);
   end Near;

   --  Two equal variables split a budget: each is a half.
   procedure Test_Split (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Pr : constant Problem := Two (Hi => One);
      St : State := Cold (2, 1);
   begin
      Assert (Solved (Pr, Default_Settings, St) = Certified, "certified");
      Near (St.X (1), One / 2, "x1");
      Near (St.X (2), One / 2, "x2");
      Assert
        (Certificate.Certified (Pr, St, Default_Settings.Tol),
         "its certificate");
   end Test_Split;

   --  A cap that binds holds its variable there.
   procedure Test_Cap_Binds (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Pr : Problem := Two (Q => [-One, 0], Hi => One);
      St : State := Cold (2, 1);
   begin
      Pr.Hi (1) := 3 * One / 4;
      Assert (Solved (Pr, Default_Settings, St) = Certified, "certified");
      Near (St.X (1), 3 * One / 4, "held at its cap");
      Near (St.X (2), One / 4, "the rest");
   end Test_Cap_Binds;

   --  An at-most budget with nothing pulling toward it is not met.
   procedure Test_At_Most (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Pr : constant Problem :=
        Two
          (Q      => [-One, -One],
           Hi     => One,
           Row_Lo => No_Lower,
           Row_Hi => One / 2);
      St : State := Cold (2, 1);
   begin
      Assert (Solved (Pr, Default_Settings, St) = Certified, "certified");
      Near (St.X (1), One / 4, "x1 at the budget's share");
      Near (St.X (2), One / 4, "x2");
   end Test_At_Most;

   --  A linear program: P = 0.  Maximize x1 + 2 x2 with x in [0, 1] and
   --  x1 + x2 at most 1.5.
   procedure Test_Linear (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Pr : constant Problem :=
        With_P
          (Two
             (Q      => [-One, -2 * One],
              Hi     => One,
              Row_Lo => No_Lower,
              Row_Hi => 3 * One / 2),
           [[0, 0], [0, 0]]);
      St : State := Cold (2, 1);
   begin
      Assert (Solved (Pr, Default_Settings, St) = Certified, "certified");
      Near (St.X (1), One / 2, "x1");
      Near (St.X (2), One, "x2 at its cap");
   end Test_Linear;

   --  Bounds no x meets.
   procedure Test_Infeasible (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      St : State := Cold (2, 1);
   begin
      Assert
        (Solved (Two (Hi => One / 4), Default_Settings, St) = Infeasible,
         "infeasible");
   end Test_Infeasible;

   --  A P with a negative eigenvalue.
   procedure Test_Not_Convex (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      St : State := Cold (2, 1);
   begin
      Assert
        (Solved
           (With_P (Two (Hi => One), [[One, 0], [0, -One]]),
            Default_Settings,
            St)
         = Not_Convex,
         "not convex");
   end Test_Not_Convex;

   --  A linear program whose objective falls without end along an open
   --  bound.
   procedure Test_Unbounded (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Pr : Problem :=
        With_P
          (Two
             (Q      => [-One, 0],
              Hi     => One,
              Row_Lo => No_Lower,
              Row_Hi => No_Upper),
           [[0, 0], [0, 0]]);
      St : State := Cold (2, 1);
   begin
      Pr.Hi (1) := No_Upper;
      Assert (Solved (Pr, Default_Settings, St) = Unbounded, "unbounded");
   end Test_Unbounded;

   --  The cap reached first.
   procedure Test_Exhausted (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      St : State := Cold (2, 1);
   begin
      Assert
        (Solved
           (Two (Hi => One), (Default_Settings with delta Max_Iter => 3), St)
         = Exhausted,
         "exhausted");
      Assert (St.Iterations = 3, "three iterations");
   end Test_Exhausted;

   --  A warm start from a near problem's answer takes fewer iterations
   --  than a cold one.
   procedure Test_Warm (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Near_Pr : constant Problem := Two (Q => [-One / 10, 0], Hi => One);
      Pr      : constant Problem := Two (Q => [-One / 8, 0], Hi => One);
      Warm    : State := Cold (2, 1);
      Cold_St : State := Cold (2, 1);
   begin
      Assert (Solved (Near_Pr, Default_Settings, Warm) = Certified, "first");
      Warm.Iterations := 0;
      Assert (Solved (Pr, Default_Settings, Warm) = Certified, "warm");
      Assert (Solved (Pr, Default_Settings, Cold_St) = Certified, "cold");
      Assert
        (Warm.Iterations < Cold_St.Iterations,
         "warm" & Warm.Iterations'Image & ", cold" & Cold_St.Iterations'Image);
   end Test_Warm;

   --  A fixture's problem solved from cold: its outcome, iterations, and
   --  the largest gap to the oracle's answer.
   type Fixture_Run is record
      Result     : Outcome;
      Iterations : Natural;
      Worst      : Raw;
   end record;

   function Run_Fixture (Name : String; S : Settings) return Fixture_Run is
      Pr  : constant Problem := Abacus_Qp_Fixtures.Load (Name);
      St  : State := Cold (Pr.N, Pr.K);
      Run : Fixture_Run;
   begin
      Run.Result := Solved (Pr, S, St);
      Run.Iterations := St.Iterations;
      Run.Worst := 0;
      if Abacus_Qp_Fixtures.Has_Answer (Name) then
         declare
            Want : constant Vector := Abacus_Qp_Fixtures.Answer (Name);
         begin
            for I in Want'Range loop
               Run.Worst := Raw'Max (Run.Worst, abs (St.X (I) - Want (I)));
            end loop;
         end;
      end if;
      return Run;
   end Run_Fixture;

   --  A millionth: the bar the answers of the fixtures are held to.
   Millionth : constant := One / 1_000_000;

   function Report (R : Fixture_Run) return String
   is (R.Result'Image
       & " after"
       & R.Iterations'Image
       & " iterations, worst"
       & R.Worst'Image
       & " units");

   --  120 assets, 44 held, 35 at their cap, an at-most budget binding
   --  beside an exact one: certified, within a millionth of OSQP's.
   procedure Test_Spread (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      R : constant Fixture_Run := Run_Fixture ("spread", Default_Settings);
   begin
      Assert (R.Result = Certified and then R.Worst <= Millionth, Report (R));
   end Test_Spread;

   --  The conditional value-at-risk linear program is not certified:
   --  ADMM, like OSQP (which runs to 400,000 iterations on it), creeps
   --  at residuals near 1e-6, so the cap is reached.  What holds is that
   --  it is reported as such, never as certified, and that the weights
   --  are within a thousandth of the simplex's.
   procedure Test_Cvar (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Thousandth : constant := One / 1_000;
      R          : constant Fixture_Run :=
        Run_Fixture ("cvar", (Default_Settings with delta Max_Iter => 40_000));
   begin
      Assert (R.Result = Exhausted and then R.Worst <= Thousandth, Report (R));
   end Test_Cvar;

   procedure Test_Fixture_Refusals
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Infeasible_Run : constant Fixture_Run :=
        Run_Fixture ("infeasible", Default_Settings);
      Nonconvex_Run  : constant Fixture_Run :=
        Run_Fixture ("nonconvex", Default_Settings);
   begin
      Assert (Infeasible_Run.Result = Infeasible, Report (Infeasible_Run));
      Assert (Nonconvex_Run.Result = Not_Convex, Report (Nonconvex_Run));
   end Test_Fixture_Refusals;

   overriding
   procedure Register_Tests (T : in out Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine (T, Test_Split'Access, "A budget split in two");
      Register_Routine (T, Test_Cap_Binds'Access, "A cap that binds");
      Register_Routine (T, Test_At_Most'Access, "An at-most budget");
      Register_Routine (T, Test_Linear'Access, "A linear program");
      Register_Routine (T, Test_Infeasible'Access, "Infeasible");
      Register_Routine (T, Test_Not_Convex'Access, "Not convex");
      Register_Routine (T, Test_Unbounded'Access, "Unbounded");
      Register_Routine (T, Test_Exhausted'Access, "Exhausted");
      Register_Routine (T, Test_Warm'Access, "A warm start");
      Register_Routine (T, Test_Spread'Access, "The spread fixture");
      Register_Routine (T, Test_Cvar'Access, "The CVaR linear program");
      Register_Routine
        (T,
         Test_Fixture_Refusals'Access,
         "Infeasible and non-convex fixtures");
   end Register_Tests;

   overriding
   function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("Abacus.Qp.Engine");
   end Name;

end Abacus_Qp_Engine_Tests;
