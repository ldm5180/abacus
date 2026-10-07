with AUnit.Assertions; use AUnit.Assertions;

with Abacus;             use Abacus;
with Abacus.Qp;          use Abacus.Qp;
with Abacus.Qp.Admm;
use type Abacus.Qp.Admm.Prepare_Result;
with Abacus.Qp.Certificate;
with Abacus.Qp.Polish;   use Abacus.Qp.Polish;
with Abacus_Qp_Fixtures;
with Abacus_Qp_Problems; use Abacus_Qp_Problems;

package body Abacus_Qp_Polish_Tests is

   --  Maximize x1 + 2 x2 with x in [0, 1] and x1 + x2 at most 1.5: the
   --  answer is the vertex (0.5, 1).
   function Linear return Problem
   is (With_P
         (Two
            (Q      => [-One, -2 * One],
             Hi     => One,
             Row_Lo => No_Lower,
             Row_Hi => 3 * One / 2),
          [[0, 0], [0, 0]]));

   --  St after Count iterations of ADMM from cold, in Work.
   procedure Iterated
     (Pr : Problem; Count : Natural; Work : in out Workspace; St : out State)
   is
      Setup : Admm.Prepare_Result;
      Ok    : Boolean := True;
   begin
      St := Cold (Pr.N, Pr.K);
      Admm.Prepare (Pr, Default_Settings, Work, Setup);
      Assert (Setup = Admm.Ready, "prepared");
      for K in 1 .. Count loop
         Admm.Iterate (Pr, Default_Settings, Work, St, Ok);
         exit when not Ok;
      end loop;
      Assert (Ok, "iterated");
   end Iterated;

   --  A bound is held when the constraint lies nearer it than its
   --  multiplier pulls; an equality row always is.
   procedure Test_Held (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Pr   : constant Problem := Two (Hi => One);
      Work : Workspace (2, 1);
      St   : State := Cold (2, 1);
   begin
      St.Z := [0, One / 2];
      St.Y := [-One / 2, 0];
      Read_Held (Pr, St, Work);
      Assert (Work.Box_Side = [At_Lower, Free], "x1 at its lower bound");
      Assert (Work.Row_Side = [1 => At_Lower], "the equality row");
      St.Z := [One / 2, One];
      St.Y := [0, One / 4];
      Read_Held (Pr, St, Work);
      Assert (Work.Box_Side = [Free, At_Upper], "x2 at its upper bound");
      St.Y := [0, -One / 4];
      Read_Held (Pr, St, Work);
      Assert (Work.Box_Side = [Free, Free], "pulled away from its bound");
   end Test_Held;

   --  A held bound whose multiplier has the wrong sign is released; with
   --  none, the most violated free constraint is held.
   procedure Test_Correct (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Pr      : constant Problem := Linear;
      Work    : Workspace (2, 1);
      Cand    : State := Cold (2, 1);
      Changed : Boolean;
   begin
      Work.Box_Side := [At_Lower, At_Upper];
      Work.Row_Side := [Free];
      Cand.X := [0, One];
      Cand.Y := [One, One];
      Correct (Pr, Cand, Work, Changed);
      Assert (Changed, "changed");
      Assert
        (Work.Box_Side = [Free, At_Upper],
         "x1's multiplier pushes from its lower bound: released");
      Cand.X := [One, One];
      Cand.Y := [0, One];
      Correct (Pr, Cand, Work, Changed);
      Assert
        (Changed and then Work.Row_Side = [1 => At_Upper],
         "the row, past its upper bound, held");
      Correct (Pr, (Cand with delta X => [One / 2, One]), Work, Changed);
      Assert (not Changed, "nothing wrong, nothing changed");
   end Test_Correct;

   --  A rough iterate of a linear program polishes to its vertex exactly.
   procedure Test_Vertex (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Pr     : constant Problem := Linear;
      Work   : Workspace (2, 1);
      St     : State (2, 1);
      Passed : Boolean;
   begin
      Iterated (Pr, 20, Work, St);
      Run (Pr, Default_Settings, Work, St, Passed);
      Assert (Passed, "certified");
      Assert (abs (St.X (1) - One / 2) <= 16, "x1" & St.X (1)'Image);
      Assert (abs (St.X (2) - One) <= 16, "x2" & St.X (2)'Image);
      Assert
        (Certificate.Certified (Pr, St, Default_Settings.Tol),
         "its certificate");
   end Test_Vertex;

   --  The tail-mean program, boxed: ADMM alone creeps near 1e-6, but its
   --  iterate holds the right bounds early, and the polish certifies it
   --  within a millionth of the simplex's answer.
   procedure Test_Tail (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Millionth : constant := One / 1_000_000;
      Iters     : constant := 3_000;
      Pr        : constant Problem := Abacus_Qp_Fixtures.Load ("tail_bounded");
      Want      : constant Vector :=
        Abacus_Qp_Fixtures.Answer ("tail_bounded");
      Work      : Workspace (Pr.N, Pr.K);
      St        : State (Pr.N, Pr.K);
      Passed    : Boolean;
      Worst     : Raw := 0;
   begin
      Iterated (Pr, Iters, Work, St);
      Run (Pr, Default_Settings, Work, St, Passed);
      Assert (Passed, "certified");
      for I in Want'Range loop
         Worst := Raw'Max (Worst, abs (St.X (I) - Want (I)));
      end loop;
      Assert (Worst <= Millionth, "worst" & Worst'Image);
   end Test_Tail;

   --  A polish from nowhere near the answer is refused, and leaves the
   --  iterate as it was.
   procedure Test_Refused (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Pr     : constant Problem := Abacus_Qp_Fixtures.Load ("tail_bounded");
      Work   : Workspace (Pr.N, Pr.K);
      St     : State (Pr.N, Pr.K);
      Passed : Boolean;
   begin
      Iterated (Pr, 0, Work, St);
      Run (Pr, Default_Settings, Work, St, Passed);
      Assert (not Passed, "not certified");
      Assert (St = Cold (Pr.N, Pr.K), "the iterate kept");
   end Test_Refused;

   --  A cone's rows are never held: a polish holds bounds as equalities,
   --  and a cone is curved.  A problem with a cone is not polished.
   procedure Test_Cone_Not_Held (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Pr     : constant Problem := Disc ([-One, -One], One);
      Work   : Workspace (2, 3);
      St     : State := Disc_Answer;
      Passed : Boolean;
   begin
      Read_Held (Pr, St, Work);
      Assert (Work.Row_Side = [Free, Free, Free], "no cone row held");
      Run (Pr, Default_Settings, Work, St, Passed);
      Assert (not Passed and then St = Disc_Answer, "not polished");
   end Test_Cone_Not_Held;

   overriding
   procedure Register_Tests (T : in out Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine (T, Test_Held'Access, "The bounds an iterate holds");
      Register_Routine (T, Test_Correct'Access, "One correction at a time");
      Register_Routine (T, Test_Vertex'Access, "A vertex, exactly");
      Register_Routine (T, Test_Tail'Access, "The boxed tail program");
      Register_Routine (T, Test_Refused'Access, "A polish refused");
      Register_Routine
        (T, Test_Cone_Not_Held'Access, "A cone is neither held nor polished");
   end Register_Tests;

   overriding
   function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("Abacus.Qp.Polish");
   end Name;

end Abacus_Qp_Polish_Tests;
