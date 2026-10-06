with Ada.Characters.Handling;
with Ada.Strings.Fixed;
with Ada.Strings.Maps;
with Interfaces; use Interfaces;

with Abacus;      use Abacus;
with Abacus.Ieee; use Abacus.Ieee;

with Abacus_Steps.Flows;

package body Abacus_Steps.Ieee is

   --  Unread until a pattern is read; Reading while its read settles;
   --  then Valued when it read as a value, or Refused when it did not.
   type State is (Unread, Reading, Valued, Refused);

   type Guard_Kind is
     (Always, Pattern_Given, Read_Ok, Units_Given, Ratio_Given, Outcome_Named);

   type Action_Kind is
     (A_Nothing,
      A_Read,
      A_Check_Units,
      A_Check_Ratio,
      A_Check_Outcome,
      A_Refuse_Pattern,
      A_Refuse_Units,
      A_Refuse_Ratio,
      A_Refuse_Outcome,
      A_Refuse_Valued,
      A_Refuse_Refused);

   subtype Check_Action is Action_Kind range A_Check_Units .. A_Check_Outcome;
   subtype Refuse_Action is
     Action_Kind range A_Refuse_Pattern .. A_Refuse_Refused;

   function Lower (S : String) return String
   renames Ada.Characters.Handling.To_Lower;

   function Got (Ctx : Step_Context) return Abacus.Ieee.Read
   is (Ctx.W.Bits.Got);

   --  The layouts a step may name.
   type Layout is (Binary64, Binary32);

   function Layout_Said (Ctx : Step_Context) return String
   is (Lower (Fabula.Args.Word (Ctx.A, 1)));

   function Is_Layout (Ctx : Step_Context) return Boolean
   is (for some L in Layout => Lower (L'Image) = Layout_Said (Ctx));

   function Hex (Ctx : Step_Context) return String
   is (Fabula.Args.Word (Ctx.A, 2));

   function Is_Hex (C : Character) return Boolean
   is (C in '0' .. '9' | 'A' .. 'F' | 'a' .. 'f');

   --  How many hexadecimal figures a layout's pattern has.
   function Figures (L : Layout) return Positive
   is (if L = Binary64 then 16 else 8);

   function Pattern_Read (Ctx : Step_Context) return Boolean
   is (Is_Layout (Ctx)
       and then Hex (Ctx)'Length = Figures (Layout'Value (Layout_Said (Ctx)))
       and then (for all C of Hex (Ctx) => Is_Hex (C)));

   function Bits_Of (Ctx : Step_Context) return Unsigned_64
   is (Unsigned_64'Value ("16#" & Hex (Ctx) & "#"));

   --  An outcome as a sentence names it: "not a number".
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

   function Evaluate
     (G : Guard_Kind; Ctx : Step_Context; Evt : Step_Kind) return Boolean
   is
      pragma Unreferenced (Evt);
   begin
      return
        (case G is
           when Always        => True,
           when Pattern_Given => Pattern_Read (Ctx),
           when Read_Ok       => Got (Ctx).Outcome = Ok,
           when Units_Given   => Units_Read (Ctx),
           when Ratio_Given   => Ratio_Read (Ctx),
           when Outcome_Named => Is_Outcome (Ctx));
   end Evaluate;

   procedure Read_Pattern (Ctx : in out Step_Context) is
   begin
      Ctx.W.Bits.Got :=
        (if Layout'Value (Layout_Said (Ctx)) = Binary64
         then From_Binary64 (Bits_Of (Ctx))
         else From_Binary32 (Unsigned_32 (Bits_Of (Ctx))));
      Then_Take (Ctx, E_Bits_Settled);
   end Read_Pattern;

   procedure Check_Value (Ctx : in out Step_Context; Want : Val) is
   begin
      Fabula.Check.Is_True
        (Ctx.R,
         Got (Ctx).Value = Want,
         "the bits read as" & Got (Ctx).Value'Image & " units");
   end Check_Value;

   procedure Check (A : Check_Action; Ctx : in out Step_Context) is
   begin
      case A is
         when A_Check_Units   =>
            Check_Value (Ctx, Units_Of (Ctx));

         when A_Check_Ratio   =>
            Check_Value (Ctx, Ratio_Of (Ctx));

         when A_Check_Outcome =>
            Fabula.Check.Text_Equal
              (Ctx.R,
               Spoken (Got (Ctx).Outcome),
               Outcome_Said (Ctx),
               "the refusal");
      end case;
   end Check;

   procedure Refuse (A : Refuse_Action; Ctx : in out Step_Context) is
   begin
      case A is
         when A_Refuse_Pattern =>
            Fabula.Check.Fail_Step
              (Ctx.R,
               "a pattern is binary64 with 16 hexadecimal figures or"
               & " binary32 with 8");

         when A_Refuse_Units   =>
            Refuse_Units (Ctx);

         when A_Refuse_Ratio   =>
            Refuse_Ratio (Ctx);

         when A_Refuse_Outcome =>
            Fabula.Check.Fail_Step
              (Ctx.R,
               "no refusal named "
               & Outcome_Said (Ctx)
               & ": not a number, infinite or out of range");

         when A_Refuse_Valued  =>
            Fabula.Check.Fail_Step
              (Ctx.R, "the bits read, as" & Got (Ctx).Value'Image & " units");

         when A_Refuse_Refused =>
            Fabula.Check.Fail_Step
              (Ctx.R,
               "the bits were refused as " & Spoken (Got (Ctx).Outcome));
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
            Read_Pattern (Ctx);

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

   Read_Bits          : constant Ev := (Kind => E_Read_Bits);
   Bits_Settled       : constant Ev := (Kind => E_Bits_Settled);
   Check_Bits_Units   : constant Ev := (Kind => E_Check_Bits_Units);
   Check_Bits_Ratio   : constant Ev := (Kind => E_Check_Bits_Ratio);
   Check_Bits_Refused : constant Ev := (Kind => E_Check_Bits_Refused);

   --!format off
   Table : constant Transition_Table :=
     [Unread  + Read_Bits          (Pattern_Given) / A_Read           >= Reading,
      Unread  + Read_Bits                          / A_Refuse_Pattern >= Unread,
      Valued  + Read_Bits          (Pattern_Given) / A_Read           >= Reading,
      Valued  + Read_Bits                          / A_Refuse_Pattern >= Valued,
      Refused + Read_Bits          (Pattern_Given) / A_Read           >= Reading,
      Refused + Read_Bits                          / A_Refuse_Pattern >= Refused,
      Reading + Bits_Settled       (Read_Ok)                          >= Valued,
      Reading + Bits_Settled                                          >= Refused,
      Valued  + Check_Bits_Units   (Units_Given)   / A_Check_Units    >= Valued,
      Valued  + Check_Bits_Units                   / A_Refuse_Units   >= Valued,
      Valued  + Check_Bits_Ratio   (Ratio_Given)   / A_Check_Ratio    >= Valued,
      Valued  + Check_Bits_Ratio                   / A_Refuse_Ratio   >= Valued,
      Valued  + Check_Bits_Refused                 / A_Refuse_Valued  >= Valued,
      Refused + Check_Bits_Refused (Outcome_Named) / A_Check_Outcome  >= Refused,
      Refused + Check_Bits_Refused                 / A_Refuse_Outcome >= Refused,
      Refused + Check_Bits_Units                   / A_Refuse_Refused >= Refused,
      Refused + Check_Bits_Ratio                   / A_Refuse_Refused >= Refused];
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

end Abacus_Steps.Ieee;
