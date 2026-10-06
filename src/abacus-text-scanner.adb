with Sml.Machines;
with Sml.Machines.Operators;

package body Abacus.Text.Scanner
  with SPARK_Mode
is

   --  Where the scan stands: before anything, after a sign, among the
   --  whole digits, just past a point with or without whole digits
   --  before it, among the fraction digits, just past the exponent's
   --  mark or its sign, among the exponent's digits, and at the end.
   type Scan_State is
     (Start,
      Signed,
      Whole,
      Point,
      Bare_Point,
      Fraction,
      Mark,
      Mark_Signed,
      Exponent,
      Done);

   --  One kind per character class; anything else is E_Other, which no
   --  row takes.
   type Event_Kind is (E_Digit, E_Sign, E_Point, E_Mark, E_End, E_Other);

   type Scan_Event (Kind : Event_Kind := E_Other) is record
      case Kind is
         when E_Digit =>
            D : Digit;

         when E_Sign =>
            Minus : Boolean;

         when others =>
            null;
      end case;
   end record;

   --  A digit needs room among the figures.
   type Guard_Kind is (Always, Room);

   type Action_Kind is
     (Nothing,
      Push_Whole,
      Push_Fraction,
      Set_Sign,
      Push_Exponent,
      Set_Exp_Sign);

   function Kind_Of (E : Scan_Event) return Event_Kind
   is (E.Kind);

   function Evaluate
     (G : Guard_Kind; Ctx : Number; Evt : Scan_Event) return Boolean
   is
      pragma Unreferenced (Evt);
   begin
      return
        (case G is
           when Always => True,
           when Room   => Ctx.Count < Max_Text);
   end Evaluate;

   --  A digit appended to the number's figures, when there is room.  The
   --  Room guard has already said there is; the engine does not tell the
   --  prover so, and the test costs nothing.
   procedure Push (Ctx : in out Number; D : Digit) is
   begin
      if Ctx.Count < Max_Text then
         Ctx.Count := Ctx.Count + 1;
         Ctx.Figures (Ctx.Count) := D;
      end if;
   end Push;

   --  An exponent digit, saturating at Max_Exponent.
   procedure Push_Exp (Ctx : in out Number; D : Digit) is
   begin
      Ctx.Exponent :=
        (if Ctx.Exponent > (Max_Exponent - D) / 10
         then Max_Exponent
         else Ctx.Exponent * 10 + D);
   end Push_Exp;

   function Digit_Of (Evt : Scan_Event) return Digit
   is (if Evt.Kind = E_Digit then Evt.D else 0);

   function Minus_Of (Evt : Scan_Event) return Boolean
   is (Evt.Kind = E_Sign and then Evt.Minus);

   procedure Execute (A : Action_Kind; Ctx : in out Number; Evt : Scan_Event)
   is
   begin
      case A is
         when Nothing       =>
            null;

         when Push_Whole    =>
            Push (Ctx, Digit_Of (Evt));
            Ctx.Whole := Ctx.Count;

         when Push_Fraction =>
            Push (Ctx, Digit_Of (Evt));

         when Set_Sign      =>
            Ctx.Negative := Minus_Of (Evt);

         when Push_Exponent =>
            Push_Exp (Ctx, Digit_Of (Evt));

         when Set_Exp_Sign  =>
            Ctx.Exp_Negative := Minus_Of (Evt);
      end case;
   end Execute;

   package SM is new
     Sml.Machines
       (State       => Scan_State,
        Event_Kind  => Event_Kind,
        Event       => Scan_Event,
        Context     => Number,
        Guard_Kind  => Guard_Kind,
        Action_Kind => Action_Kind,
        Kind_Of     => Kind_Of,
        Evaluate    => Evaluate,
        Execute     => Execute);

   package Op is new SM.Operators (Always => Always, Nothing => Nothing);
   use SM, Op;

   Digit_Ev : constant Ev := (Kind => E_Digit);
   Sign     : constant Ev := (Kind => E_Sign);
   Dot      : constant Ev := (Kind => E_Point);
   Exp_Mark : constant Ev := (Kind => E_Mark);
   End_Ev   : constant Ev := (Kind => E_End);

   --  From + Event (Guard) / Action >= To.  A number needs a digit
   --  before its point or after it, and an exponent needs a digit after
   --  its mark.
   --!format off
   Table : constant Transition_Table :=
     [Start       + Digit_Ev (Room) / Push_Whole    >= Whole,
      Start       + Sign            / Set_Sign      >= Signed,
      Start       + Dot                             >= Bare_Point,
      Signed      + Digit_Ev (Room) / Push_Whole    >= Whole,
      Signed      + Dot                             >= Bare_Point,
      Whole       + Digit_Ev (Room) / Push_Whole    >= Whole,
      Whole       + Dot                             >= Point,
      Whole       + Exp_Mark                        >= Mark,
      Whole       + End_Ev                          >= Done,
      Point       + Digit_Ev (Room) / Push_Fraction >= Fraction,
      Point       + Exp_Mark                        >= Mark,
      Point       + End_Ev                          >= Done,
      Bare_Point  + Digit_Ev (Room) / Push_Fraction >= Fraction,
      Fraction    + Digit_Ev (Room) / Push_Fraction >= Fraction,
      Fraction    + Exp_Mark                        >= Mark,
      Fraction    + End_Ev                          >= Done,
      Mark        + Digit_Ev        / Push_Exponent >= Exponent,
      Mark        + Sign            / Set_Exp_Sign  >= Mark_Signed,
      Mark_Signed + Digit_Ev        / Push_Exponent >= Exponent,
      Exponent    + Digit_Ev        / Push_Exponent >= Exponent,
      Exponent    + End_Ev                          >= Done];
   --!format on

   function Classify (C : Character) return Scan_Event
   is (case C is
         when '0' .. '9' =>
           (Kind => E_Digit, D => Character'Pos (C) - Character'Pos ('0')),
         when '+' | '-'  => (Kind => E_Sign, Minus => C = '-'),
         when '.'        => (Kind => E_Point),
         when 'e' | 'E'  => (Kind => E_Mark),
         when others     => (Kind => E_Other));

   function Scan (Text : String) return Scan_Result is
      M       : Machine := Make (Table, Initial => Start);
      Result  : Scan_Result;
      Handled : Boolean;
   begin
      for I in Text'Range loop
         Process_Event (M, Result.Number, Classify (Text (I)), Handled);
         if not Handled then
            Result.Error := Unexpected;
            Result.Position := I - Text'First + 1;
            return Result;
         end if;
      end loop;
      Process_Event (M, Result.Number, (Kind => E_End), Handled);
      if Handled
        and then State_Of (M) = Done
        and then Result.Number.Whole <= Result.Number.Count
      then
         Result.Ok := True;
         Result.Error := None;
      else
         Result.Error := Incomplete;
      end if;
      return Result;
   end Scan;

end Abacus.Text.Scanner;
