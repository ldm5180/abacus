with AUnit.Assertions; use AUnit.Assertions;

with Abacus;         use Abacus;
with Abacus.Qp;      use Abacus.Qp;
with Abacus.Qp.Admm;
with Abacus.Qp.Held; use Abacus.Qp.Held;

package body Abacus_Qp_Held_Tests is

   --  Within a few units: the held systems are refined, not exact.
   Few : constant := 64;

   procedure Near (Got, Want : Val; What : String) is
   begin
      Assert (abs (Got - Want) <= Few, What & Got'Image);
   end Near;

   --  Work prepared for Pr, as a solve leaves it before it polishes.
   procedure Prepared (Pr : Problem; Work : out Workspace) is
      Result : Admm.Prepare_Result;
   begin
      Admm.Prepare (Pr, Default_Settings, Work, Result);
   end Prepared;

   --  Three variables in [0, 1], no quadratic term, two rows: x1 + x2
   --  and x1 - x2, each between -1 and 1; x3 in neither.
   function Three return Problem
   is ((N      => 3,
        K      => 2,
        P      => [others => [others => 0]],
        Q      => [-One, -2 * One, 0],
        Lo     => [0, 0, 0],
        Hi     => [One, One, One],
        E      => [[One, One, 0], [One, -One, 0]],
        Row_Lo => [-One, -One],
        Row_Hi => [One, One],
        Kind   => [Interval, Interval]));

   --  Both rows held at their upper bounds, x3 at its lower: the vertex
   --  x1 + x2 = 1, x1 - x2 = 1 is (1, 0, 0), whatever the cost; the rows'
   --  multipliers balance the cost given, -(c1, c2) = A'lambda.
   procedure Test_Solve_For_Cost (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Pr   : constant Problem := Three;
      Work : Workspace (3, 2);
      Cand : State := Cold (3, 2);
      Ok   : Boolean;
   begin
      Prepared (Pr, Work);
      Work.Box_Side := [Free, Free, At_Lower];
      Work.Row_Side := [At_Upper, At_Upper];
      Solve (Pr, [-One, -3 * One, 0], Work, Cand, Ok);
      Assert (Ok, "solved");
      Near (Cand.X (1), One, "x1");
      Near (Cand.X (2), 0, "x2");
      --  lambda1 + lambda2 = 1, lambda1 - lambda2 = 3
      Near (Cand.Y_Row (1), 2 * One, "lambda1");
      Near (Cand.Y_Row (2), -One, "lambda2");
   end Test_Solve_For_Cost;

   --  With the held system factored, A z = v and A'w = c are solved:
   --  A = [[1, 1], [1, -1]], so z = ((v1 + v2) / 2, (v1 - v2) / 2), and
   --  A' is A.
   procedure Test_Square (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Pr   : constant Problem := Three;
      Work : Workspace (3, 2);
      Cand : State := Cold (3, 2);
      Ok   : Boolean;
      Z    : Vector (1 .. 3);
      W    : Vector (1 .. 2);
   begin
      Prepared (Pr, Work);
      Work.Box_Side := [Free, Free, At_Lower];
      Work.Row_Side := [At_Upper, At_Upper];
      Solve (Pr, Pr.Q, Work, Cand, Ok);
      Direction (Pr, Work, [3 * One, One], Z, Ok);
      Assert (Ok, "directed");
      Near (Z (1), 2 * One, "z1");
      Near (Z (2), One, "z2");
      Prices (Pr, Work, [One, 3 * One, 0], W, Ok);
      Assert (Ok, "priced");
      Near (W (1), 2 * One, "w1");
      Near (W (2), -One, "w2");
   end Test_Square;

   --  A held row that repeats another over the free columns is named;
   --  failing one, a free column that repeats another.
   procedure Test_Dependence (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Pr    : Problem := Three;
      Work  : Workspace (3, 2);
      Found : Dependence;
      Ok    : Boolean;
   begin
      Prepared (Pr, Work);
      Work.Box_Side := [Free, Free, At_Lower];
      Work.Row_Side := [At_Upper, At_Upper];
      Find_Dependence (Pr, Work, Found, Ok);
      Assert (Ok and then Found = Dependence'(0, 0), "independent");
      Pr.E (2, 1) := 2 * One;
      Pr.E (2, 2) := 2 * One;
      Find_Dependence (Pr, Work, Found, Ok);
      Assert (Ok and then Found.Row = 2, "the second row repeats the first");
      Work.Row_Side := [At_Upper, Free];
      Find_Dependence (Pr, Work, Found, Ok);
      Assert
        (Ok and then Found = Dependence'(0, 2),
         "two free columns over one row: the second");
   end Test_Dependence;

   overriding
   procedure Register_Tests (T : in out Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T, Test_Solve_For_Cost'Access, "Held, solved for a cost given");
      Register_Routine (T, Test_Square'Access, "The square system, both ways");
      Register_Routine
        (T, Test_Dependence'Access, "A dependent row, a dependent column");
   end Register_Tests;

   overriding
   function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("Abacus.Qp.Held");
   end Name;

end Abacus_Qp_Held_Tests;
