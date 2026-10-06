with Fabula.Args;
with Fabula.Check;
with Fabula.Frames;
with Fabula.Registry;

with Abacus;

--  The step registry the feature runner dispatches on: one Step_Kind
--  per pattern, one table that reads like the features, and one Execute
--  that offers each step to every feature's state machine.

package Abacus_Steps is

   --  The steps, grouped by the feature that reads them.  Each is an
   --  event of that feature's state machine, in its own child package.
   type Step_Kind is (E_Check_One);

   type Hook_Kind is (Fresh_World);

   --  What one scenario holds.  fabula copies it per step, so it holds
   --  values only.
   type World is record
      Result : Abacus.Raw := 0;
   end record;

   --  One step as a machine sees it: the scenario, the step's arguments,
   --  frame and outcome, and the event an action asks to be taken next
   --  (Then_Take), which the runner posts before the step returns.
   type Step_Context is record
      W        : World;
      A        : Fabula.Args.List;
      Info     : Fabula.Frames.Frame;
      R        : Fabula.Check.Outcome;
      Has_Next : Boolean := False;
      Next     : Step_Kind := Step_Kind'First;
   end record;

   procedure Then_Take (Ctx : in out Step_Context; Evt : Step_Kind);

   --  Whether capture N reads as a whole number of units.
   function Units_Read (Ctx : Step_Context; N : Positive := 1) return Boolean;

   --  Capture N, which Units_Read said reads.
   function Units_Of (Ctx : Step_Context; N : Positive := 1) return Abacus.Raw
   with Pre => Units_Read (Ctx, N);

   --  Fail the step for capture N: why it does not read as units.
   procedure Refuse_Units (Ctx : in out Step_Context; N : Positive := 1);

   package Steps is new
     Fabula.Registry
       (Step_Kind => Step_Kind,
        Hook_Kind => Hook_Kind,
        Context   => World);
   use Steps;

   --!format off
   Step_Defs : constant Steps.Step_Table :=
     [Step ("one is {int} units")            >= E_Check_One];
   --!format on

   Hook_Defs : constant Steps.Hook_Table := [Before >= Fresh_World];

   procedure Execute
     (S    : Step_Kind;
      Ctx  : in out World;
      A    : Fabula.Args.List;
      Info : Fabula.Frames.Frame;
      R    : in out Fabula.Check.Outcome);

   procedure Run_Hook
     (H    : Hook_Kind;
      Ctx  : in out World;
      Info : Fabula.Frames.Frame;
      R    : in out Fabula.Check.Outcome);

end Abacus_Steps;
