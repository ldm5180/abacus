with Fabula.Args;
with Fabula.Check;
with Fabula.Frames;
with Fabula.Registry;

with Abacus;
with Abacus.Arith;
with Abacus.Ieee;
with Abacus.Text;

--  The step registry the feature runner dispatches on: one Step_Kind
--  per pattern, one table that reads like the features, and one Execute
--  that offers each step to every feature's state machine.

package Abacus_Steps is

   --  The steps, grouped by the feature that reads them.  Each is an
   --  event of that feature's state machine, in its own child package.
   type Step_Kind is
     (E_Check_One,
      E_Give_Units,
      E_Give_Whole,
      E_Give_Ratio,
      E_Multiply,
      E_Divide,
      E_Check_Units,
      E_Check_Ratio,
      E_Check_Status,
      E_Check_Extreme,
      E_Read_Text,
      E_Text_Settled,
      E_Check_Writes_Back,
      E_Check_Written,
      E_Check_Read_Units,
      E_Check_Read_Ratio,
      E_Check_Refused,
      E_Check_Position,
      E_Read_Bits,
      E_Bits_Settled,
      E_Check_Bits_Units,
      E_Check_Bits_Ratio,
      E_Check_Bits_Refused);

   type Hook_Kind is (Fresh_World);

   --  The two operands arithmetic.feature names.
   type Operand is (A, B);

   type Operand_Values is array (Operand) of Abacus.Val;
   type Operand_Flags is array (Operand) of Boolean;

   --  Arithmetic's operands, the ones given so far, and the last result
   --  with its status.
   type Sums is record
      Value  : Operand_Values := [others => 0];
      Given  : Operand_Flags := [others => False];
      Result : Abacus.Arith.Checked;
   end record;

   --  The text text.feature last read, and what it read as.
   type Reading is record
      Got : Abacus.Text.Read;
   end record;

   --  The bit pattern ieee.feature last read, and what it read as.
   type Pattern is record
      Got : Abacus.Ieee.Read;
   end record;

   --  What one scenario holds.  fabula copies it per step, so it holds
   --  values only.
   type World is record
      Arith : Sums;
      Text  : Reading;
      Bits  : Pattern;
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

   --  Whether capture N reads as a whole number a value holds.
   function Whole_Read (Ctx : Step_Context; N : Positive := 1) return Boolean;

   --  Fail the step for capture N: why it is not a whole value.
   procedure Refuse_Whole (Ctx : in out Step_Context; N : Positive := 1);

   --  Whether captures N and N + 1 read as a fraction whose numerator
   --  and denominator are whole values and whose denominator is not
   --  zero.
   function Ratio_Read (Ctx : Step_Context; N : Positive := 1) return Boolean;

   --  The value nearest the fraction captures N and N + 1 spell.
   function Ratio_Of (Ctx : Step_Context; N : Positive := 1) return Abacus.Val
   with Pre => Ratio_Read (Ctx, N);

   --  Fail the step for the fraction at captures N and N + 1.
   procedure Refuse_Ratio (Ctx : in out Step_Context; N : Positive := 1);

   package Steps is new
     Fabula.Registry
       (Step_Kind => Step_Kind,
        Hook_Kind => Hook_Kind,
        Context   => World);
   use Steps;

   --!format off
   Step_Defs : constant Steps.Step_Table :=
     [Step ("the value one is {int} units")  >= E_Check_One,
      Step ("{word} is {int} units")         >= E_Give_Units,
      Step ("{word} is {int}")               >= E_Give_Whole,
      Step ("{word} is {int} over {int}")    >= E_Give_Ratio,
      Step ("{word} is multiplied by {word}")
                                             >= E_Multiply,
      Step ("{word} is divided by {word}")   >= E_Divide,
      Step ("the result is {int} units")     >= E_Check_Units,
      Step ("the result is {int} over {int}")
                                             >= E_Check_Ratio,
      Step ("the result is {word}")          >= E_Check_Status,
      Step ("the result is the {word} value")
                                             >= E_Check_Extreme,
      Step ("the text {string} is read")     >= E_Read_Text,
      Step ("an empty text is read")         >= E_Read_Text,
      Step ("the text writes back as {string}")
                                             >= E_Check_Writes_Back,
      Step ("written to {int} places it is {string}")
                                             >= E_Check_Written,
      Step ("the text reads as {int} units") >= E_Check_Read_Units,
      Step ("the text reads as {int} over {int}")
                                             >= E_Check_Read_Ratio,
      Step ("the text is refused as {}")     >= E_Check_Refused,
      Step ("the refusal is at position {int}")
                                             >= E_Check_Position,
      Step ("the {word} bits {word} are read")
                                             >= E_Read_Bits,
      Step ("the bits read as {int} units")  >= E_Check_Bits_Units,
      Step ("the bits read as {int} over {int}")
                                             >= E_Check_Bits_Ratio,
      Step ("the bits are refused as {}")    >= E_Check_Bits_Refused];
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
