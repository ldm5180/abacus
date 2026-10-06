with Ada.Characters.Handling;
with Ada.Strings.Fixed;
with Ada.Strings.Maps;

with Abacus;      use Abacus;
with Abacus.Text; use Abacus.Text;

with Abacus_Steps.Flows;

package body Abacus_Steps.Text is

   --  Unread until a text is read; Reading while its read settles; then
   --  Valued when it read as a value, or Refused when it did not.
   type State is (Unread, Reading, Valued, Refused);

   type Guard_Kind is
     (Always, Read_Ok, Units_Given, Ratio_Given, Places_Given, Error_Named);

   type Action_Kind is
     (A_Nothing,
      A_Read,
      A_Check_Back,
      A_Check_Written,
      A_Check_Units,
      A_Check_Ratio,
      A_Check_Error,
      A_Check_Position,
      A_Refuse_Units,
      A_Refuse_Ratio,
      A_Refuse_Places,
      A_Refuse_Error,
      A_Refuse_Valued,
      A_Refuse_Refused);

   subtype Check_Action is Action_Kind range A_Check_Back .. A_Check_Position;
   subtype Refuse_Action is
     Action_Kind range A_Refuse_Units .. A_Refuse_Refused;

   function Got (Ctx : Step_Context) return Abacus.Text.Read
   is (Ctx.W.Text.Got);

   --  An error kind as a sentence names it: "out of range".
   function Spoken (E : Error_Kind) return String is
      Name : String := Ada.Characters.Handling.To_Lower (E'Image);
   begin
      Ada.Strings.Fixed.Translate
        (Name, Ada.Strings.Maps.To_Mapping ("_", " "));
      return Name;
   end Spoken;

   function Error_Said (Ctx : Step_Context) return String
   is (Ada.Characters.Handling.To_Lower (Fabula.Args.Text (Ctx.A, 1)));

   function Is_Error (Ctx : Step_Context) return Boolean
   is (for some E in Error_Kind => Spoken (E) = Error_Said (Ctx));

   --  The text a read step names: its capture, or none for the empty
   --  text.
   function Text_Given (Ctx : Step_Context) return String
   is (if Fabula.Args.Count (Ctx.A) = 0
       then ""
       else Fabula.Args.Text (Ctx.A, 1));

   function Places_Read (Ctx : Step_Context) return Boolean
   is (Units_Read (Ctx) and then Units_Of (Ctx) in 0 .. Max_Places);

   function Evaluate
     (G : Guard_Kind; Ctx : Step_Context; Evt : Step_Kind) return Boolean
   is
      pragma Unreferenced (Evt);
   begin
      return
        (case G is
           when Always       => True,
           when Read_Ok      => Got (Ctx).Ok,
           when Units_Given  => Units_Read (Ctx),
           when Ratio_Given  => Ratio_Read (Ctx),
           when Places_Given => Places_Read (Ctx),
           when Error_Named  => Is_Error (Ctx));
   end Evaluate;

   procedure Check_Text (Ctx : in out Step_Context; Places : Place_Count) is
   begin
      Fabula.Check.Text_Equal
        (Ctx.R,
         Image (Got (Ctx).Value, Places),
         Fabula.Args.Text (Ctx.A, Fabula.Args.Count (Ctx.A)),
         "the value written");
   end Check_Text;

   procedure Check_Value (Ctx : in out Step_Context; Want : Val) is
   begin
      Fabula.Check.Is_True
        (Ctx.R,
         Got (Ctx).Value = Want,
         "the text reads as"
         & Got (Ctx).Value'Image
         & " units; want"
         & Want'Image);
   end Check_Value;

   procedure Check (A : Check_Action; Ctx : in out Step_Context) is
   begin
      case A is
         when A_Check_Back     =>
            Check_Text (Ctx, Max_Places);

         when A_Check_Written  =>
            Check_Text (Ctx, Place_Count (Units_Of (Ctx)));

         when A_Check_Units    =>
            Check_Value (Ctx, Units_Of (Ctx));

         when A_Check_Ratio    =>
            Check_Value (Ctx, Ratio_Of (Ctx));

         when A_Check_Error    =>
            Fabula.Check.Text_Equal
              (Ctx.R,
               Spoken (Got (Ctx).Error),
               Error_Said (Ctx),
               "the refusal");

         when A_Check_Position =>
            Fabula.Check.Is_True
              (Ctx.R,
               Raw (Got (Ctx).Position) = Units_Of (Ctx),
               "the refusal is at position" & Got (Ctx).Position'Image);
      end case;
   end Check;

   procedure Refuse (A : Refuse_Action; Ctx : in out Step_Context) is
   begin
      case A is
         when A_Refuse_Units   =>
            Refuse_Units (Ctx);

         when A_Refuse_Ratio   =>
            Refuse_Ratio (Ctx);

         when A_Refuse_Places  =>
            Fabula.Check.Fail_Step
              (Ctx.R, "places run from 0 to" & Max_Places'Image);

         when A_Refuse_Error   =>
            Fabula.Check.Fail_Step
              (Ctx.R,
               "no refusal named "
               & Error_Said (Ctx)
               & ": empty, unexpected, incomplete, too long or out of range");

         when A_Refuse_Valued  =>
            Fabula.Check.Fail_Step
              (Ctx.R,
               "the text was read, as" & Got (Ctx).Value'Image & " units");

         when A_Refuse_Refused =>
            Fabula.Check.Fail_Step
              (Ctx.R, "the text was refused as " & Spoken (Got (Ctx).Error));
      end case;
   end Refuse;

   procedure Execute
     (A : Action_Kind; Ctx : in out Step_Context; Evt : Step_Kind)
   is
      pragma Unreferenced (Evt);
   begin
      case A is
         when A_Nothing     =>
            null;

         when A_Read        =>
            Ctx.W.Text.Got := Parse (Text_Given (Ctx));
            Then_Take (Ctx, E_Text_Settled);

         when Check_Action  =>
            Check (A, Ctx);

         when Refuse_Action =>
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

   Read_Text         : constant Ev := (Kind => E_Read_Text);
   Text_Settled      : constant Ev := (Kind => E_Text_Settled);
   Check_Writes_Back : constant Ev := (Kind => E_Check_Writes_Back);
   Check_Written     : constant Ev := (Kind => E_Check_Written);
   Check_Read_Units  : constant Ev := (Kind => E_Check_Read_Units);
   Check_Read_Ratio  : constant Ev := (Kind => E_Check_Read_Ratio);
   Check_Refused     : constant Ev := (Kind => E_Check_Refused);
   Check_Position    : constant Ev := (Kind => E_Check_Position);

   --!format off
   Table : constant Transition_Table :=
     [Unread  + Read_Text                        / A_Read           >= Reading,
      Valued  + Read_Text                        / A_Read           >= Reading,
      Refused + Read_Text                        / A_Read           >= Reading,
      Reading + Text_Settled      (Read_Ok)                         >= Valued,
      Reading + Text_Settled                                        >= Refused,
      Valued  + Check_Writes_Back                / A_Check_Back     >= Valued,
      Valued  + Check_Written     (Places_Given) / A_Check_Written  >= Valued,
      Valued  + Check_Written                    / A_Refuse_Places  >= Valued,
      Valued  + Check_Read_Units  (Units_Given)  / A_Check_Units    >= Valued,
      Valued  + Check_Read_Units                 / A_Refuse_Units   >= Valued,
      Valued  + Check_Read_Ratio  (Ratio_Given)  / A_Check_Ratio    >= Valued,
      Valued  + Check_Read_Ratio                 / A_Refuse_Ratio   >= Valued,
      Valued  + Check_Refused                    / A_Refuse_Valued  >= Valued,
      Valued  + Check_Position                   / A_Refuse_Valued  >= Valued,
      Refused + Check_Refused     (Error_Named)  / A_Check_Error    >= Refused,
      Refused + Check_Refused                    / A_Refuse_Error   >= Refused,
      Refused + Check_Position    (Units_Given)  / A_Check_Position >= Refused,
      Refused + Check_Position                   / A_Refuse_Units   >= Refused,
      Refused + Check_Writes_Back                / A_Refuse_Refused >= Refused,
      Refused + Check_Written                    / A_Refuse_Refused >= Refused,
      Refused + Check_Read_Units                 / A_Refuse_Refused >= Refused,
      Refused + Check_Read_Ratio                 / A_Refuse_Refused >= Refused];
   --!format on

   Current : State := Unread;

   procedure Offer
     (Ctx : in out Step_Context; Evt : Step_Kind; Handled : out Boolean) is
   begin
      Flow.Take (Table, Current, Ctx, Evt, Handled);
   end Offer;

   procedure Reset is
   begin
      Current := Unread;
   end Reset;

   function Phase return String
   is (Current'Image);

end Abacus_Steps.Text;
