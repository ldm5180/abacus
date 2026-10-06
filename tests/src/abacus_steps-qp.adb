with Ada.Characters.Handling;
with Ada.Strings.Fixed;
with Ada.Strings.Maps;

with Abacus;    use Abacus;
with Abacus.Qp; use Abacus.Qp;
with Abacus.Qp.Engine;
with Abacus.Text;

with Abacus_Qp_Fixtures;
with Abacus_Steps.Flows;

package body Abacus_Steps.Qp is

   --  Empty until a problem is posed; Posed while its parts are given,
   --  or Loaded from a fixture;
   --  Settling while a solve's outcome settles; then Answered when it
   --  was certified, or Refused when it was not.
   type Stage is (Empty, Posed, Loaded, Settling, Answered, Refused);

   type Guard_Kind is
     (Always,
      Size_Read,
      Diagonal_Read,
      Bounds_Read,
      Upper_Read,
      Variable_Read,
      Objective_Read,
      Total_Read,
      Is_Certified,
      Outcome_Named,
      Value_Read,
      Variable_Value_Read,
      Fixture_Read,
      Count_Read);

   type Action_Kind is
     (A_Nothing,
      A_Pose_Identity,
      A_Pose_Linear,
      A_Pose_Diagonal,
      A_Bound_All,
      A_Bound_Upper,
      A_Open_Upper,
      A_Objective,
      A_Sum_Exactly,
      A_Sum_At_Most,
      A_Solve,
      A_Solve_Warm,
      A_Load,
      A_Solve_Fixture,
      A_Check_Outcome,
      A_Check_Each,
      A_Check_Variable,
      A_Check_Fewer,
      A_Check_Oracle,
      A_Check_Held,
      A_Refuse_Pose,
      A_Refuse_Part,
      A_Refuse_Outcome,
      A_Refuse_Value,
      A_Refuse_Uncertified,
      A_Refuse_Certified,
      A_Refuse_Unposed);

   subtype Pose_Action is Action_Kind range A_Pose_Identity .. A_Sum_At_Most;
   subtype Check_Action is Action_Kind range A_Check_Outcome .. A_Check_Held;
   subtype Refuse_Action is
     Action_Kind range A_Refuse_Pose .. A_Refuse_Unposed;

   function Lower (S : String) return String
   renames Ada.Characters.Handling.To_Lower;

   --  The answers are read to a billionth.
   Billionth : constant := One / 1_000_000_000;

   ---------------------------------------------------------------------
   --  The problem posed, and solving it.
   ---------------------------------------------------------------------

   function Size_Fits (Ctx : Step_Context) return Boolean
   is (Units_Read (Ctx) and then Units_Of (Ctx) in 1 .. Max_Variables);

   function Variable_Fits (Ctx : Step_Context) return Boolean
   is (Units_Read (Ctx) and then Units_Of (Ctx) in 1 .. Raw (Ctx.W.Qp.N));

   function List_Fits (Ctx : Step_Context; N : Positive) return Boolean
   is (Parse_List (Fabula.Args.Text (Ctx.A, N)).Ok
       and then Parse_List (Fabula.Args.Text (Ctx.A, N)).Count = Ctx.W.Qp.N);

   function List (Ctx : Step_Context; N : Positive) return Small_Vector
   is (Parse_List (Fabula.Args.Text (Ctx.A, N)).Values (1 .. Max_Variables));

   procedure Pose (Ctx : in out Step_Context; Diagonal : Small_Vector) is
      N : constant Variable_Count := Variable_Count (Units_Of (Ctx));
   begin
      Ctx.W.Qp := (N => N, others => <>);
      for I in 1 .. N loop
         Ctx.W.Qp.P (I, I) := Diagonal (I);
         Ctx.W.Qp.Hi (I) := One;
      end loop;
   end Pose;

   --  The problem the world holds, as the library takes it.
   function Problem_Of (G : Program) return Problem is
      Pr : Problem (G.N, (if G.Has_Row then 1 else 0));
   begin
      for I in 1 .. G.N loop
         for J in 1 .. G.N loop
            Pr.P (I, J) := G.P (I, J);
         end loop;
         Pr.Q (I) := G.Q (I);
         Pr.Lo (I) := G.Lo (I);
         Pr.Hi (I) := G.Hi (I);
      end loop;
      Pr.E := [others => [others => One]];
      Pr.Row_Lo := [others => G.Row_Lo];
      Pr.Row_Hi := [others => G.Row_Hi];
      return Pr;
   end Problem_Of;

   --  The iterate the world holds: its last answer, or a cold start.
   function State_Of (G : Program; Warm : Boolean) return State is
      St : State := Cold (G.N, (if G.Has_Row then 1 else 0));
   begin
      if Warm then
         St.X := G.X (1 .. G.N);
         St.Z := G.Z (1 .. G.N);
         St.Y := G.Y (1 .. G.N);
         St.Z_Row := [others => G.Z_Row];
         St.Y_Row := [others => G.Y_Row];
      end if;
      return St;
   end State_Of;

   procedure Keep (G : in out Program; St : State; Result : Outcome) is
   begin
      G.Result := Result;
      G.X (1 .. G.N) := St.X;
      G.Z (1 .. G.N) := St.Z;
      G.Y (1 .. G.N) := St.Y;
      if St.K = 1 then
         G.Z_Row := St.Z_Row (1);
         G.Y_Row := St.Y_Row (1);
      end if;
      G.Iterations := St.Iterations;
   end Keep;

   --  Solve the world's problem, cold or from its last answer.
   procedure Solve (G : in out Program; Warm : Boolean) is
      Pr     : constant Problem := Problem_Of (G);
      Work   : Workspace (Pr.N, Pr.K);
      St     : State := State_Of (G, Warm);
      Result : Outcome;
   begin
      Engine.Solve (Pr, Default_Settings, Work, St, Result);
      Keep (G, St, Result);
   end Solve;

   --  The warm solve: the new objective, the iterations a cold start
   --  takes, then the solve from the last answer.
   procedure Solve_Warm (Ctx : in out Step_Context) is
      G : Program renames Ctx.W.Qp;
      C : Program;
   begin
      G.Q := List (Ctx, 1);
      C := G;
      Solve (C, Warm => False);
      G.Cold := C.Iterations;
      Solve (G, Warm => True);
   end Solve_Warm;

   --  The fixtures tools/make_qp.py wrote.
   function Is_Fixture (Name : String) return Boolean
   is (Name in "spread" | "tail" | "infeasible" | "nonconvex");

   function Fixture_Name (G : Program) return String
   is (G.Fixture (1 .. G.Named));

   procedure Load (Ctx : in out Step_Context) is
      Name : constant String := Fabula.Args.Word (Ctx.A, 1);
   begin
      Ctx.W.Qp := (Named => Name'Length, others => <>);
      Ctx.W.Qp.Fixture (1 .. Name'Length) := Name;
   end Load;

   --  The largest gap from X to the oracle's answer, when there is one.
   function Gap_To_Oracle (Name : String; X : Vector) return Raw is
      Worst : Raw := 0;
   begin
      if Abacus_Qp_Fixtures.Has_Answer (Name) then
         declare
            Want : constant Vector := Abacus_Qp_Fixtures.Answer (Name);
         begin
            for I in Want'Range loop
               Worst := Raw'Max (Worst, abs (X (I) - Want (I)));
            end loop;
         end;
      end if;
      return Worst;
   end Gap_To_Oracle;

   procedure Solve_Fixture (G : in out Program) is
      Pr   : constant Problem := Abacus_Qp_Fixtures.Load (Fixture_Name (G));
      Work : Workspace (Pr.N, Pr.K);
      St   : State := Cold (Pr.N, Pr.K);
   begin
      Engine.Solve (Pr, Default_Settings, Work, St, G.Result);
      G.Iterations := St.Iterations;
      G.Worst := Gap_To_Oracle (Fixture_Name (G), St.X);
      G.Held := 0;
      for V of St.X loop
         G.Held := G.Held + (if V > Billionth then 1 else 0);
      end loop;
   end Solve_Fixture;

   ---------------------------------------------------------------------
   --  Outcomes by name.
   ---------------------------------------------------------------------

   --  An outcome as a sentence names it: "not convex".
   function Spoken (O : Outcome) return String is
      Name : String := Lower (O'Image);
   begin
      Ada.Strings.Fixed.Translate
        (Name, Ada.Strings.Maps.To_Mapping ("_", " "));
      return Name;
   end Spoken;

   function Outcome_Said (Ctx : Step_Context) return String
   is (Lower (Fabula.Args.Text (Ctx.A, 1)));

   function Is_Outcome (Ctx : Step_Context) return Boolean
   is (for some O in Outcome => Spoken (O) = Outcome_Said (Ctx));

   function Near (Got, Want : Val) return Boolean
   is (abs (Got - Want) <= Billionth);

   ---------------------------------------------------------------------
   --  The machine.
   ---------------------------------------------------------------------

   function Evaluate
     (G : Guard_Kind; Ctx : Step_Context; Evt : Step_Kind) return Boolean
   is
      pragma Unreferenced (Evt);
   begin
      return
        (case G is
           when Always              => True,
           when Size_Read           => Size_Fits (Ctx),
           when Diagonal_Read       =>
             Size_Fits (Ctx)
             and then Parse_List (Fabula.Args.Text (Ctx.A, 2)).Ok
             and then Raw (Parse_List (Fabula.Args.Text (Ctx.A, 2)).Count)
                      = Units_Of (Ctx),
           when Bounds_Read         =>
             Decimal_Read (Ctx, 1) and then Decimal_Read (Ctx, 2),
           when Upper_Read          =>
             Variable_Fits (Ctx) and then Decimal_Read (Ctx, 2),
           when Variable_Read       => Variable_Fits (Ctx),
           when Objective_Read      => List_Fits (Ctx, 1),
           when Total_Read          => Decimal_Read (Ctx),
           when Is_Certified        => Ctx.W.Qp.Result = Certified,
           when Outcome_Named       => Is_Outcome (Ctx),
           when Value_Read          => Decimal_Read (Ctx),
           when Variable_Value_Read =>
             Variable_Fits (Ctx) and then Decimal_Read (Ctx, 2),
           when Fixture_Read        =>
             Is_Fixture (Fabula.Args.Word (Ctx.A, 1)),
           when Count_Read          => Units_Read (Ctx));
   end Evaluate;

   procedure Pose_Part (A : Pose_Action; Ctx : in out Step_Context) is
      G : Program renames Ctx.W.Qp;
   begin
      case A is
         when A_Pose_Identity =>
            Pose (Ctx, [others => One]);

         when A_Pose_Linear   =>
            Pose (Ctx, [others => 0]);

         when A_Pose_Diagonal =>
            Pose
              (Ctx,
               Parse_List (Fabula.Args.Text (Ctx.A, 2)).Values
                 (1 .. Max_Variables));

         when A_Bound_All     =>
            G.Lo := [others => Decimal_Of (Ctx, 1)];
            G.Hi := [others => Decimal_Of (Ctx, 2)];

         when A_Bound_Upper   =>
            G.Hi (Natural (Units_Of (Ctx))) := Decimal_Of (Ctx, 2);

         when A_Open_Upper    =>
            G.Hi (Natural (Units_Of (Ctx))) := No_Upper;

         when A_Objective     =>
            G.Q := List (Ctx, 1);

         when A_Sum_Exactly   =>
            G :=
              (G
               with delta
                 Has_Row => True,
                 Row_Lo  => Decimal_Of (Ctx),
                 Row_Hi  => Decimal_Of (Ctx));

         when A_Sum_At_Most   =>
            G :=
              (G
               with delta
                 Has_Row => True,
                 Row_Lo  => No_Lower,
                 Row_Hi  => Decimal_Of (Ctx));
      end case;
   end Pose_Part;

   procedure Check (A : Check_Action; Ctx : in out Step_Context) is
      G : Program renames Ctx.W.Qp;
   begin
      case A is
         when A_Check_Outcome  =>
            Fabula.Check.Text_Equal
              (Ctx.R, Spoken (G.Result), Outcome_Said (Ctx), "the outcome");

         when A_Check_Each     =>
            Fabula.Check.Is_True
              (Ctx.R,
               (for all I in 1 .. G.N => Near (G.X (I), Decimal_Of (Ctx))),
               "variable 1 is " & Abacus.Text.Image (G.X (1)));

         when A_Check_Variable =>
            Fabula.Check.Is_True
              (Ctx.R,
               Near (G.X (Natural (Units_Of (Ctx))), Decimal_Of (Ctx, 2)),
               "it is " & Abacus.Text.Image (G.X (Natural (Units_Of (Ctx)))));

         when A_Check_Fewer    =>
            Fabula.Check.Is_True
              (Ctx.R,
               G.Iterations < G.Cold,
               "warm" & G.Iterations'Image & ", cold" & G.Cold'Image);

         when A_Check_Oracle   =>
            Fabula.Check.Is_True
              (Ctx.R,
               G.Worst <= Decimal_Of (Ctx),
               "the largest gap is " & Abacus.Text.Image (G.Worst));

         when A_Check_Held     =>
            Fabula.Check.Is_True
              (Ctx.R,
               Raw (G.Held) >= Units_Of (Ctx),
               G.Held'Image & " variables are above zero");
      end case;
   end Check;

   function Refusal (A : Refuse_Action; Ctx : Step_Context) return String
   is (case A is
         when A_Refuse_Pose        =>
           "a problem has 1 to"
           & Max_Variables'Image
           & " variables, or is one of the fixtures: spread, tail,"
           & " infeasible, nonconvex",
         when A_Refuse_Part        =>
           "a bound or a total is a decimal number, a variable one of the"
           & " problem's, and an objective one number per variable",
         when A_Refuse_Outcome     =>
           "no outcome named "
           & Outcome_Said (Ctx)
           & ": certified, infeasible, unbounded, not convex, stalled,"
           & " exhausted or diverged",
         when A_Refuse_Value       => "a variable is checked against a number",
         when A_Refuse_Uncertified =>
           "the outcome is " & Spoken (Ctx.W.Qp.Result),
         when A_Refuse_Certified   => "the answer was certified",
         when A_Refuse_Unposed     => "no problem has been posed and solved");

   procedure Execute
     (A : Action_Kind; Ctx : in out Step_Context; Evt : Step_Kind)
   is
      pragma Unreferenced (Evt);
   begin
      case A is
         when A_Nothing       =>
            null;

         when Pose_Action     =>
            Pose_Part (A, Ctx);

         when A_Solve         =>
            Solve (Ctx.W.Qp, Warm => False);
            Then_Take (Ctx, E_Qp_Settled);

         when A_Solve_Warm    =>
            Solve_Warm (Ctx);
            Then_Take (Ctx, E_Qp_Settled);

         when A_Load          =>
            Load (Ctx);

         when A_Solve_Fixture =>
            Solve_Fixture (Ctx.W.Qp);
            Then_Take (Ctx, E_Qp_Settled);

         when Check_Action    =>
            Check (A, Ctx);

         when Refuse_Action   =>
            Fabula.Check.Fail_Step (Ctx.R, Refusal (A, Ctx));
      end case;
   end Execute;

   package Flow is new
     Abacus_Steps.Flows
       (State       => Stage,
        Guard_Kind  => Guard_Kind,
        Action_Kind => Action_Kind,
        Evaluate    => Evaluate,
        Execute     => Execute,
        Always      => Always,
        Nothing     => A_Nothing);

   use Flow.Machines;
   use Flow.Op;

   Pose_Identity   : constant Ev := (Kind => E_Pose_Identity);
   Pose_Linear     : constant Ev := (Kind => E_Pose_Linear);
   Pose_Diagonal   : constant Ev := (Kind => E_Pose_Diagonal);
   Bound_All       : constant Ev := (Kind => E_Bound_All);
   Bound_Upper     : constant Ev := (Kind => E_Bound_Upper);
   Open_Upper      : constant Ev := (Kind => E_Open_Upper);
   Give_Objective  : constant Ev := (Kind => E_Give_Objective);
   Sum_Exactly     : constant Ev := (Kind => E_Sum_Exactly);
   Sum_At_Most     : constant Ev := (Kind => E_Sum_At_Most);
   Solve_Qp        : constant Ev := (Kind => E_Solve_Qp);
   Solve_Warm_Ev   : constant Ev := (Kind => E_Solve_Warm);
   Qp_Settled      : constant Ev := (Kind => E_Qp_Settled);
   Check_Certified : constant Ev := (Kind => E_Check_Certified);
   Check_Outcome   : constant Ev := (Kind => E_Check_Outcome);
   Check_Each      : constant Ev := (Kind => E_Check_Each);
   Check_Variable  : constant Ev := (Kind => E_Check_Variable);
   Check_Fewer     : constant Ev := (Kind => E_Check_Fewer);
   Load_Fixture    : constant Ev := (Kind => E_Load_Fixture);
   Check_Oracle    : constant Ev := (Kind => E_Check_Oracle);
   Check_Held      : constant Ev := (Kind => E_Check_Held);

   --!format off
   Table : constant Transition_Table :=
     [Empty    + Pose_Identity   (Size_Read)           / A_Pose_Identity      >= Posed,
      Empty    + Pose_Identity                         / A_Refuse_Pose        >= Empty,
      Empty    + Pose_Linear     (Size_Read)           / A_Pose_Linear        >= Posed,
      Empty    + Pose_Linear                           / A_Refuse_Pose        >= Empty,
      Empty    + Pose_Diagonal   (Diagonal_Read)       / A_Pose_Diagonal      >= Posed,
      Empty    + Pose_Diagonal                         / A_Refuse_Pose        >= Empty,
      Empty    + Load_Fixture    (Fixture_Read)        / A_Load               >= Loaded,
      Empty    + Load_Fixture                          / A_Refuse_Pose        >= Empty,
      Loaded   + Solve_Qp                              / A_Solve_Fixture      >= Settling,
      Empty    + Solve_Qp                              / A_Refuse_Unposed     >= Empty,
      Empty    + Check_Certified                       / A_Refuse_Unposed     >= Empty,
      Posed    + Bound_All       (Bounds_Read)         / A_Bound_All          >= Posed,
      Posed    + Bound_All                             / A_Refuse_Part        >= Posed,
      Posed    + Bound_Upper     (Upper_Read)          / A_Bound_Upper        >= Posed,
      Posed    + Bound_Upper                           / A_Refuse_Part        >= Posed,
      Posed    + Open_Upper      (Variable_Read)       / A_Open_Upper         >= Posed,
      Posed    + Open_Upper                            / A_Refuse_Part        >= Posed,
      Posed    + Give_Objective  (Objective_Read)      / A_Objective          >= Posed,
      Posed    + Give_Objective                        / A_Refuse_Part        >= Posed,
      Posed    + Sum_Exactly     (Total_Read)          / A_Sum_Exactly        >= Posed,
      Posed    + Sum_Exactly                           / A_Refuse_Part        >= Posed,
      Posed    + Sum_At_Most     (Total_Read)          / A_Sum_At_Most        >= Posed,
      Posed    + Sum_At_Most                           / A_Refuse_Part        >= Posed,
      Posed    + Solve_Qp                              / A_Solve              >= Settling,
      Settling + Qp_Settled      (Is_Certified)                               >= Answered,
      Settling + Qp_Settled                                                   >= Refused,
      Answered + Solve_Warm_Ev   (Objective_Read)      / A_Solve_Warm         >= Settling,
      Answered + Solve_Warm_Ev                         / A_Refuse_Part        >= Answered,
      Answered + Check_Certified                                              >= Answered,
      Answered + Check_Outcome   (Outcome_Named)       / A_Check_Outcome      >= Answered,
      Answered + Check_Outcome                         / A_Refuse_Outcome     >= Answered,
      Answered + Check_Each      (Value_Read)          / A_Check_Each         >= Answered,
      Answered + Check_Each                            / A_Refuse_Value       >= Answered,
      Answered + Check_Variable  (Variable_Value_Read) / A_Check_Variable     >= Answered,
      Answered + Check_Variable                        / A_Refuse_Value       >= Answered,
      Answered + Check_Fewer                           / A_Check_Fewer        >= Answered,
      Answered + Check_Oracle    (Value_Read)          / A_Check_Oracle       >= Answered,
      Answered + Check_Oracle                          / A_Refuse_Value       >= Answered,
      Answered + Check_Held      (Count_Read)          / A_Check_Held         >= Answered,
      Answered + Check_Held                            / A_Refuse_Value       >= Answered,
      Refused  + Check_Outcome   (Outcome_Named)       / A_Check_Outcome      >= Refused,
      Refused  + Check_Outcome                         / A_Refuse_Outcome     >= Refused,
      Refused  + Check_Certified                       / A_Refuse_Uncertified >= Refused,
      Refused  + Check_Each                            / A_Refuse_Uncertified >= Refused,
      Refused  + Check_Variable                        / A_Refuse_Uncertified >= Refused];
   --!format on

   Current : Stage := Empty;

   procedure Offer
     (Ctx : in out Step_Context; Evt : Step_Kind; Handled : out Boolean) is
   begin
      Flow.Take (Table, Current, Ctx, Evt, Handled);
   end Offer;

   procedure Reset is
   begin
      Current := Empty;
   end Reset;

   function Phase return String
   is (Current'Image);

end Abacus_Steps.Qp;
