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
      E_Check_Bits_Refused,
      E_Apply,
      E_Apply_Again,
      E_Check_Square,
      E_Check_Within,
      E_Give_Data,
      E_Take_Quantile,
      E_Check_Answer,
      E_Give_Weights,
      E_Give_Second,
      E_Compute,
      E_Check_Near,
      E_Open_Window,
      E_Give_Rows,
      E_Add_Row,
      E_Remove_Oldest,
      E_Check_Fresh,
      E_Check_Fresh_Covariance,
      E_Give_Data_Matrix,
      E_Give_Symmetric,
      E_Factor_Gram,
      E_Factor,
      E_Solve,
      E_Fit,
      E_Check_Factors,
      E_Check_Refused_At,
      E_Check_Solution,
      --  An event no pattern names: a factorization posts it, and the
      --  next row's guard reads whether it factored.
      E_Factor_Settled);

   type Hook_Kind is (Fresh_World);

   --  The most data stats.feature names in one step.
   Max_Data : constant := 64;

   subtype Data_Count is Natural range 0 .. Max_Data;

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

   --  The last result elementary.feature took.
   type Function_Result is record
      Value : Abacus.Val := 0;
   end record;

   --  The most series and rows a window in stats.feature holds, and the
   --  most rows it adds or removes in all.
   Max_Series : constant := 8;
   Max_Rows   : constant := 16;

   subtype Series_Count is Natural range 0 .. Max_Series;
   subtype Row_Count is Natural range 0 .. Max_Rows;

   type Row_Table is array (1 .. Max_Rows) of Abacus.Vector (1 .. Max_Series);

   --  What a window has been through: its series, every row it was given
   --  in order, and how many of the oldest have been removed.  A step
   --  replays it, so the slid window is built the way a caller builds
   --  one.
   type Window_Log is record
      Series  : Series_Count := 0;
      Rows    : Row_Table := [others => [others => 0]];
      Given   : Row_Count := 0;
      Removed : Row_Count := 0;
   end record;

   --  The data stats.feature holds, the weights and a second series
   --  beside them, the answer it took of them, and its window.
   type Table is record
      Data    : Abacus.Vector (1 .. Max_Data) := [others => 0];
      Count   : Data_Count := 0;
      Weights : Abacus.Vector (1 .. Max_Data) := [others => 0];
      Weighed : Data_Count := 0;
      Second  : Abacus.Vector (1 .. Max_Data) := [others => 0];
      Paired  : Data_Count := 0;
      Answer  : Abacus.Val := 0;
      Window  : Window_Log;
   end record;

   --  The largest matrix cholesky.feature states.
   Max_Side : constant := 8;

   subtype Side is Natural range 0 .. Max_Side;

   --  The matrix cholesky.feature holds, its factor and the outcome, and
   --  the last solution.
   type Factoring is record
      M        : Abacus.Matrix (1 .. Max_Side, 1 .. Max_Side) :=
        [others => [others => 0]];
      Rows     : Side := 0;
      Cols     : Side := 0;
      Refused  : Boolean := False;
      Column   : Natural := 0;
      Solution : Abacus.Vector (1 .. Max_Side) := [others => 0];
   end record;

   --  What one scenario holds.  fabula copies it per step, so it holds
   --  values only.
   type World is record
      Arith : Sums;
      Text  : Reading;
      Bits  : Pattern;
      Elem  : Function_Result;
      Stats : Table;
      Chol  : Factoring;
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

   --  A list of numbers read from a step, separated by commas.
   type Number_List is record
      Ok     : Boolean := True;
      Values : Abacus.Vector (1 .. Max_Data) := [others => 0];
      Count  : Data_Count := 0;
   end record;

   --  The decimal numbers of Text, separated by commas; Ok False when
   --  one does not read, there are more than Max_Data, or none.
   function Parse_List (Text : String) return Number_List;

   --  The position of the next Mark in Text from From, or past its end.
   function Next_Mark (Text, Mark : String; From : Positive) return Positive
   with Pre => From in Text'Range;

   --  Whether capture N reads as decimal text (Abacus.Text).
   function Decimal_Read
     (Ctx : Step_Context; N : Positive := 1) return Boolean;

   --  Capture N as a value, which Decimal_Read said reads.
   function Decimal_Of
     (Ctx : Step_Context; N : Positive := 1) return Abacus.Val
   with Pre => Decimal_Read (Ctx, N);

   --  Fail the step for capture N: why it is not decimal text.
   procedure Refuse_Decimal (Ctx : in out Step_Context; N : Positive := 1);

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
      Step ("the bits are refused as {}")    >= E_Check_Bits_Refused,
      Step ("the {word} of the result is taken")
                                             >= E_Apply_Again,
      Step ("the {word} of {word} is taken") >= E_Apply,
      Step ("its square is {word} within {int} units")
                                             >= E_Check_Square,
      Step ("the result is {word} within {word}")
                                             >= E_Check_Within,
      Step ("the data {}")                   >= E_Give_Data,
      Step ("the {word} quantile is taken by the {word} rule")
                                             >= E_Take_Quantile,
      Step ("the answer is {word}")          >= E_Check_Answer,
      Step ("the weights {}")                >= E_Give_Weights,
      Step ("the second series {}")          >= E_Give_Second,
      Step ("the {} is computed")            >= E_Compute,
      Step ("the answer is within {word} of {word}")
                                             >= E_Check_Near,
      Step ("a window over {int} series")    >= E_Open_Window,
      Step ("the rows {}")                   >= E_Give_Rows,
      Step ("the row {} is added")           >= E_Add_Row,
      Step ("the oldest row is removed")     >= E_Remove_Oldest,
      Step ("the window's sums equal a fresh window's over its rows")
                                             >= E_Check_Fresh,
      Step ("the sample covariance of series {int} and {int} is the fresh one's")
                                             >= E_Check_Fresh_Covariance,
      Step ("the matrix of observations:")   >= E_Give_Data_Matrix,
      Step ("the symmetric matrix:")         >= E_Give_Symmetric,
      Step ("its Gram matrix is factored with a floor of {word}")
                                             >= E_Factor_Gram,
      Step ("it is factored with a floor of {word}")
                                             >= E_Factor,
      Step ("it is solved for {}")           >= E_Solve,
      Step ("the column {} is fitted by least squares with a ridge of {word}")
                                             >= E_Fit,
      Step ("it factors")                    >= E_Check_Factors,
      Step ("the factorization is refused at column {int}")
                                             >= E_Check_Refused_At,
      Step ("the solution is within {word} of {}")
                                             >= E_Check_Solution];
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
