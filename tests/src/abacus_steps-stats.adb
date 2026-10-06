with Ada.Characters.Handling;
with Ada.Strings.Fixed;

with Abacus;         use Abacus;
with Abacus.Sorting; use Abacus.Sorting;
with Abacus.Text;

with Abacus_Steps.Flows;

package body Abacus_Steps.Stats is

   --  Empty until data are given; Holding them; Answered once a
   --  statistic has been taken of them.
   type State is (Empty, Holding, Answered);

   type Guard_Kind is (Always, Data_Read, Quantile_Named, Answer_Read);

   type Action_Kind is
     (A_Nothing,
      A_Give,
      A_Quantile,
      A_Check_Answer,
      A_Refuse_Data,
      A_Refuse_Quantile,
      A_Refuse_Answer,
      A_Refuse_Empty);

   subtype Refuse_Action is Action_Kind range A_Refuse_Data .. A_Refuse_Empty;

   function Lower (S : String) return String
   renames Ada.Characters.Handling.To_Lower;

   --  The comma-separated numbers of a data step, read into a table.
   type Parsed_Data is record
      Ok    : Boolean := True;
      Items : Table;
   end record;

   function Parse_Data (Text : String) return Parsed_Data is
      Result : Parsed_Data;
      From   : Positive := Text'First;
      Comma  : Natural;
      Got    : Abacus.Text.Read;
   begin
      while From <= Text'Last and then Result.Ok loop
         Comma := Ada.Strings.Fixed.Index (Text (From .. Text'Last), ",");
         if Comma = 0 then
            Comma := Text'Last + 1;
         end if;
         Got :=
           Abacus.Text.Parse
             (Ada.Strings.Fixed.Trim
                (Text (From .. Comma - 1), Ada.Strings.Both));
         Result.Ok := Got.Ok and then Result.Items.Count < Max_Data;
         if Result.Ok then
            Result.Items.Count := Result.Items.Count + 1;
            Result.Items.Data (Result.Items.Count) := Got.Value;
         end if;
         From := Comma + 1;
      end loop;
      Result.Ok := Result.Ok and then Result.Items.Count > 0;
      return Result;
   end Parse_Data;

   function Data_Of (Ctx : Step_Context) return Parsed_Data
   is (Parse_Data (Fabula.Args.Text (Ctx.A, 1)));

   function Is_Method (Ctx : Step_Context) return Boolean
   is (for some M in Method =>
         Lower (M'Image) = Lower (Fabula.Args.Word (Ctx.A, 2)));

   function Evaluate
     (G : Guard_Kind; Ctx : Step_Context; Evt : Step_Kind) return Boolean
   is
      pragma Unreferenced (Evt);
   begin
      return
        (case G is
           when Always         => True,
           when Data_Read      => Data_Of (Ctx).Ok,
           when Quantile_Named =>
             Decimal_Read (Ctx)
             and then Decimal_Of (Ctx) in Probability
             and then Is_Method (Ctx),
           when Answer_Read    => Decimal_Read (Ctx));
   end Evaluate;

   function Held (Ctx : Step_Context) return Vector
   is (Ctx.W.Stats.Data (1 .. Ctx.W.Stats.Count));

   procedure Take_Quantile (Ctx : in out Step_Context) is
      Sorted : Vector := Held (Ctx);
      Order  : Order_Array (Sorted'Range);
   begin
      Sort (Sorted, Order);
      Ctx.W.Stats.Answer :=
        Quantile
          (Sorted,
           Decimal_Of (Ctx),
           Method'Value (Fabula.Args.Word (Ctx.A, 2)));
   end Take_Quantile;

   procedure Refuse (A : Refuse_Action; Ctx : in out Step_Context) is
   begin
      case A is
         when A_Refuse_Data     =>
            Fabula.Check.Fail_Step
              (Ctx.R,
               "data are up to"
               & Max_Data'Image
               & " decimal numbers separated by commas");

         when A_Refuse_Quantile =>
            Fabula.Check.Fail_Step
              (Ctx.R,
               "a quantile is a number from 0 to 1, by the nearest or the"
               & " linear rule");

         when A_Refuse_Answer   =>
            Refuse_Decimal (Ctx);

         when A_Refuse_Empty    =>
            Fabula.Check.Fail_Step (Ctx.R, "no data have been given");
      end case;
   end Refuse;

   procedure Execute
     (A : Action_Kind; Ctx : in out Step_Context; Evt : Step_Kind)
   is
      pragma Unreferenced (Evt);
   begin
      case A is
         when A_Nothing      =>
            null;

         when A_Give         =>
            Ctx.W.Stats := Data_Of (Ctx).Items;

         when A_Quantile     =>
            Take_Quantile (Ctx);

         when A_Check_Answer =>
            Fabula.Check.Text_Equal
              (Ctx.R,
               Abacus.Text.Image (Ctx.W.Stats.Answer),
               Abacus.Text.Image (Decimal_Of (Ctx)),
               "the answer");

         when Refuse_Action  =>
            Refuse (A, Ctx);
      end case;
   end Execute;

   package Flow is new
     Abacus_Steps.Flows
       (State       => State,
        Guard_Kind  => Guard_Kind,
        Action_Kind => Action_Kind,
        Evaluate    => Evaluate,
        Execute     => Execute,
        Always      => Always,
        Nothing     => A_Nothing);

   use Flow.Machines;
   use Flow.Op;

   Give_Data        : constant Ev := (Kind => E_Give_Data);
   Take_Quantile_Ev : constant Ev := (Kind => E_Take_Quantile);
   Check_Answer     : constant Ev := (Kind => E_Check_Answer);

   --!format off
   Table_Rows : constant Transition_Table :=
     [Empty    + Give_Data        (Data_Read)      / A_Give            >= Holding,
      Empty    + Give_Data                         / A_Refuse_Data     >= Empty,
      Empty    + Take_Quantile_Ev                  / A_Refuse_Empty    >= Empty,
      Empty    + Check_Answer                      / A_Refuse_Empty    >= Empty,
      Holding  + Give_Data        (Data_Read)      / A_Give            >= Holding,
      Holding  + Give_Data                         / A_Refuse_Data     >= Holding,
      Holding  + Take_Quantile_Ev (Quantile_Named) / A_Quantile        >= Answered,
      Holding  + Take_Quantile_Ev                  / A_Refuse_Quantile >= Holding,
      Answered + Give_Data        (Data_Read)      / A_Give            >= Holding,
      Answered + Give_Data                         / A_Refuse_Data     >= Answered,
      Answered + Take_Quantile_Ev (Quantile_Named) / A_Quantile        >= Answered,
      Answered + Take_Quantile_Ev                  / A_Refuse_Quantile >= Answered,
      Answered + Check_Answer     (Answer_Read)    / A_Check_Answer    >= Answered,
      Answered + Check_Answer                      / A_Refuse_Answer   >= Answered];
   --!format on

   Current : State := Empty;

   procedure Offer
     (Ctx : in out Step_Context; Evt : Step_Kind; Handled : out Boolean) is
   begin
      Flow.Take (Table_Rows, Current, Ctx, Evt, Handled);
   end Offer;

   procedure Reset is
   begin
      Current := Empty;
   end Reset;

   function Phase return String
   is (Current'Image);

end Abacus_Steps.Stats;
