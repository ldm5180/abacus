with Ada.Characters.Handling;

with Interfaces; use Interfaces;

with Abacus;       use Abacus;
with Abacus.Sobol; use Abacus.Sobol;
with Abacus.Text;

with Abacus_Steps.Flows;

package body Abacus_Steps.Sobol is

   type Guard_Kind is
     (Always,
      Plain_Read,
      Scrambled_Read,
      Count_Read,
      Block_Read,
      Is_Filled,
      Runs_Read,
      Intervals_Read,
      Same_Read,
      Seed_Read,
      Refusal_Named);

   type Action_Kind is
     (A_Nothing,
      A_Give_Plain,
      A_Give_Scrambled,
      A_Draw_Points,
      A_Draw_Block,
      A_Check_Runs,
      A_Check_Stratified,
      A_Check_Same,
      A_Check_Other,
      A_Check_Refused,
      A_Refuse_Sequence,
      A_Refuse_Count,
      A_Refuse_Check,
      A_Refuse_Unsequenced,
      A_Refuse_Undrawn,
      A_Refuse_Filled);

   subtype Check_Action is Action_Kind range A_Check_Runs .. A_Check_Refused;
   subtype Refuse_Action is
     Action_Kind range A_Refuse_Sequence .. A_Refuse_Filled;

   ---------------------------------------------------------------------
   --  Reading the steps.
   ---------------------------------------------------------------------

   function Whole_In
     (Ctx : Step_Context; N : Positive; Last : Raw) return Boolean
   is (Units_Read (Ctx, N) and then Units_Of (Ctx, N) in 1 .. Last);

   function Seed_Given (Ctx : Step_Context; N : Positive) return Boolean
   is (Units_Read (Ctx, N) and then Units_Of (Ctx, N) >= 0);

   function Seed_Of (Ctx : Step_Context; N : Positive) return Unsigned_64
   is (Unsigned_64 (Units_Of (Ctx, N)))
   with Pre => Seed_Given (Ctx, N);

   --  Whether N is a power of two.
   function Is_Power (N : Raw) return Boolean
   is (N >= 1 and then (for some M in Block_Exponent => 2**M = N));

   function Exponent_Of (N : Positive) return Block_Exponent
   is ([for M in Block_Exponent => (if 2**M = N then M else 0)]'
         Reduce ("+", 0));

   --  The points drawn, as the step names them.
   function Drawn_Count (Ctx : Step_Context) return Raw
   is (Raw (Ctx.W.Sobol.Count));

   function Runs_Given (Ctx : Step_Context) return Boolean
   is (Whole_In (Ctx, 1, Raw (Ctx.W.Sobol.D))
       and then Parse_List (Fabula.Args.Text (Ctx.A, 2)).Ok
       and then Parse_List (Fabula.Args.Text (Ctx.A, 2)).Count
                = Ctx.W.Sobol.Count);

   function Refusal_Said (Ctx : Step_Context) return String
   is (Ada.Characters.Handling.To_Lower (Fabula.Args.Word (Ctx.A, 1)));

   function Is_Refusal (Ctx : Step_Context) return Boolean
   is (for some R in Block_Result =>
         R /= Filled
         and then Ada.Characters.Handling.To_Lower (R'Image)
                  = Refusal_Said (Ctx));

   function Evaluate
     (G : Guard_Kind; Ctx : Step_Context; Evt : Step_Kind) return Boolean
   is
      pragma Unreferenced (Evt);
   begin
      return
        (case G is
           when Always         => True,
           when Plain_Read     => Whole_In (Ctx, 1, Max_Sample_Dimensions),
           when Scrambled_Read =>
             Whole_In (Ctx, 1, Max_Sample_Dimensions)
             and then Seed_Given (Ctx, 2),
           when Count_Read     => Whole_In (Ctx, 1, Max_Sample_Points),
           when Block_Read     =>
             Whole_In (Ctx, 1, Max_Sample_Points)
             and then Is_Power (Units_Of (Ctx)),
           when Is_Filled      => Ctx.W.Sobol.Result = Filled,
           when Runs_Read      => Runs_Given (Ctx),
           when Intervals_Read =>
             Units_Read (Ctx) and then Units_Of (Ctx) = Drawn_Count (Ctx),
           when Same_Read      =>
             Seed_Given (Ctx, 1)
             and then Units_Read (Ctx, 2)
             and then Units_Of (Ctx, 2) = Drawn_Count (Ctx),
           when Seed_Read      => Seed_Given (Ctx, 1),
           when Refusal_Named  => Is_Refusal (Ctx));
   end Evaluate;

   ---------------------------------------------------------------------
   --  Drawing.
   ---------------------------------------------------------------------

   --  The sequence the scenario names, from Seed when scrambled, with
   --  Skipped points passed over.
   function Sequence_Of
     (W : Sampling; Seed : Unsigned_64; Skipped : Point_Count) return Sequence
   is
      Ok : Boolean;
   begin
      return
         S : Sequence :=
           (if W.Scrambled then Scrambled (W.D, Seed) else Unscrambled (W.D))
      do
         Skip (S, Skipped, Ok);
      end return;
   end Sequence_Of;

   --  Count points from S into W's table.
   procedure Draw (S : in out Sequence; W : in out Sampling; Count : Positive)
   is
      X  : Point (1 .. W.D);
      Ok : Boolean;
   begin
      for I in 1 .. Count loop
         Next (S, X, Ok);
         for J in X'Range loop
            W.Points (I, J) := X (J);
         end loop;
      end loop;
      W.Count := Count;
   end Draw;

   procedure Draw_Points (W : in out Sampling; Count : Positive) is
      S : Sequence := Sequence_Of (W, W.Seed, W.Drawn);
   begin
      Draw (S, W, Count);
      W.Drawn := Drawn (S);
   end Draw_Points;

   procedure Draw_Block (W : in out Sampling; Size : Positive) is
      S : Sequence := Sequence_Of (W, W.Seed, W.Drawn);
      B : Block (1 .. Size, 1 .. W.D);
   begin
      Next_Block (S, Exponent_Of (Size), B, W.Result);
      if W.Result = Filled then
         for I in B'Range (1) loop
            for J in B'Range (2) loop
               W.Points (I, J) := B (I, J);
            end loop;
         end loop;
         W.Count := Size;
         W.Drawn := Drawn (S);
      end if;
   end Draw_Block;

   ---------------------------------------------------------------------
   --  Checking.
   ---------------------------------------------------------------------

   --  The first drawn point whose coordinate J is not Want's, or zero.
   function First_Off
     (W : Sampling; J : Positive; Want : Number_List) return Sample_Count is
   begin
      for I in 1 .. W.Count loop
         if Unit (W.Points (I, J)) /= Want.Values (I) then
            return I;
         end if;
      end loop;
      return 0;
   end First_Off;

   procedure Check_Runs (Ctx : in out Step_Context) is
      W    : Sampling renames Ctx.W.Sobol;
      J    : constant Positive := Positive (Units_Of (Ctx));
      Want : constant Number_List := Parse_List (Fabula.Args.Text (Ctx.A, 2));
      Off  : constant Sample_Count := First_Off (W, J, Want);
   begin
      Fabula.Check.Is_True
        (Ctx.R,
         Off = 0,
         "point"
         & Off'Image
         & " has "
         & Abacus.Text.Image (Unit (W.Points (Positive'Max (Off, 1), J)), 9));
   end Check_Runs;

   --  Whether coordinate J of the drawn points has one in each of as many
   --  equal intervals as there are points.
   function Column_Stratified (W : Sampling; J : Positive) return Boolean is
      type Seen is array (Unsigned_32 range <>) of Boolean;
      Width : constant Unsigned_64 := Period / Unsigned_64 (W.Count);
      Hit   : Seen (0 .. Unsigned_32 (W.Count) - 1) := [others => False];
      Cell  : Unsigned_32;
   begin
      for I in 1 .. W.Count loop
         Cell := Unsigned_32 (Unsigned_64 (W.Points (I, J)) / Width);
         if Hit (Cell) then
            return False;
         end if;
         Hit (Cell) := True;
      end loop;
      return True;
   end Column_Stratified;

   --  How many of the drawn points the sequence from Seed gives again, at
   --  the same places.
   function Same_Points (W : Sampling; Seed : Unsigned_64) return Natural is
      S     : Sequence :=
        Sequence_Of (W, Seed, W.Drawn - Point_Count (W.Count));
      X     : Point (1 .. W.D);
      Ok    : Boolean;
      Equal : Natural := 0;
   begin
      for I in 1 .. W.Count loop
         Next (S, X, Ok);
         Equal :=
           Equal
           + (if (for all J in X'Range => X (J) = W.Points (I, J))
              then 1
              else 0);
      end loop;
      return Equal;
   end Same_Points;

   procedure Check (A : Check_Action; Ctx : in out Step_Context) is
      W : Sampling renames Ctx.W.Sobol;
   begin
      case A is
         when A_Check_Runs       =>
            Check_Runs (Ctx);

         when A_Check_Stratified =>
            Fabula.Check.Is_True
              (Ctx.R,
               (for all J in 1 .. W.D => Column_Stratified (W, J)),
               "two points share an interval");

         when A_Check_Same       =>
            Fabula.Check.Is_True
              (Ctx.R,
               Same_Points (W, Seed_Of (Ctx, 1)) = W.Count,
               Same_Points (W, Seed_Of (Ctx, 1))'Image & " the same");

         when A_Check_Other      =>
            Fabula.Check.Is_True
              (Ctx.R,
               Same_Points (W, Seed_Of (Ctx, 1)) = 0,
               Same_Points (W, Seed_Of (Ctx, 1))'Image & " the same");

         when A_Check_Refused    =>
            Fabula.Check.Text_Equal
              (Ctx.R,
               Ada.Characters.Handling.To_Lower (W.Result'Image),
               Refusal_Said (Ctx),
               "the refusal");
      end case;
   end Check;

   function Refusal (A : Refuse_Action) return String
   is (case A is
         when A_Refuse_Sequence    =>
           "a sequence has 1 to"
           & Max_Sample_Dimensions'Image
           & " dimensions here, and a seed is a whole number",
         when A_Refuse_Count       =>
           "1 to"
           & Max_Sample_Points'Image
           & " points are drawn here, a block's a power of two",
         when A_Refuse_Check       =>
           "a check names a coordinate of the sequence and one number per"
           & " point drawn, or as many intervals or points as were drawn,"
           & " or a refusal: misaligned or past_end",
         when A_Refuse_Unsequenced => "no sequence has been named",
         when A_Refuse_Undrawn     => "no points have been drawn",
         when A_Refuse_Filled      => "the block was filled");

   procedure Execute
     (A : Action_Kind; Ctx : in out Step_Context; Evt : Step_Kind)
   is
      pragma Unreferenced (Evt);
      W : Sampling renames Ctx.W.Sobol;
   begin
      case A is
         when A_Nothing        =>
            null;

         when A_Give_Plain     =>
            W := (W with delta D => Sample_Dimension (Units_Of (Ctx)));

         when A_Give_Scrambled =>
            W :=
              (W
               with delta
                 D         => Sample_Dimension (Units_Of (Ctx)),
                 Scrambled => True,
                 Seed      => Seed_Of (Ctx, 2));

         when A_Draw_Points    =>
            Draw_Points (W, Positive (Units_Of (Ctx)));

         when A_Draw_Block     =>
            Draw_Block (W, Positive (Units_Of (Ctx)));
            Then_Take (Ctx, E_Block_Settled);

         when Check_Action     =>
            Check (A, Ctx);

         when Refuse_Action    =>
            Fabula.Check.Fail_Step (Ctx.R, Refusal (A));
      end case;
   end Execute;

   package Flow is new
     Abacus_Steps.Flows
       (State       => Sampling_Stage,
        Guard_Kind  => Guard_Kind,
        Action_Kind => Action_Kind,
        Evaluate    => Evaluate,
        Execute     => Execute,
        Always      => Always,
        Nothing     => A_Nothing);

   use Flow.Machines;
   use Flow.Op;

   Sobol_Plain         : constant Ev := (Kind => E_Sobol_Plain);
   Sobol_Scrambled     : constant Ev := (Kind => E_Sobol_Scrambled);
   Draw_Points_Ev      : constant Ev := (Kind => E_Draw_Points);
   Draw_Block_Ev       : constant Ev := (Kind => E_Draw_Block);
   Block_Settled       : constant Ev := (Kind => E_Block_Settled);
   Check_Runs_Ev       : constant Ev := (Kind => E_Check_Runs);
   Check_Stratified    : constant Ev := (Kind => E_Check_Stratified);
   Check_Same_Seed     : constant Ev := (Kind => E_Check_Same_Seed);
   Check_Other_Seed    : constant Ev := (Kind => E_Check_Other_Seed);
   Check_Block_Refused : constant Ev := (Kind => E_Check_Block_Refused);

   --!format off
   Table : constant Transition_Table :=
     [No_Sequence   + Sobol_Plain         (Plain_Read)     / A_Give_Plain         >= Given,
      No_Sequence   + Sobol_Plain                          / A_Refuse_Sequence    >= No_Sequence,
      No_Sequence   + Sobol_Scrambled     (Scrambled_Read) / A_Give_Scrambled     >= Given,
      No_Sequence   + Sobol_Scrambled                      / A_Refuse_Sequence    >= No_Sequence,
      No_Sequence   + Draw_Points_Ev                       / A_Refuse_Unsequenced >= No_Sequence,
      No_Sequence   + Draw_Block_Ev                        / A_Refuse_Unsequenced >= No_Sequence,
      Given         + Draw_Points_Ev      (Count_Read)     / A_Draw_Points        >= Sampled,
      Given         + Draw_Points_Ev                       / A_Refuse_Count       >= Given,
      Given         + Draw_Block_Ev       (Block_Read)     / A_Draw_Block         >= Drawing,
      Given         + Draw_Block_Ev                        / A_Refuse_Count       >= Given,
      Given         + Check_Runs_Ev                        / A_Refuse_Undrawn     >= Given,
      Given         + Check_Stratified                     / A_Refuse_Undrawn     >= Given,
      Drawing       + Block_Settled       (Is_Filled)                             >= Sampled,
      Drawing       + Block_Settled                                               >= Block_Refused,
      Sampled       + Draw_Points_Ev      (Count_Read)     / A_Draw_Points        >= Sampled,
      Sampled       + Draw_Points_Ev                       / A_Refuse_Count       >= Sampled,
      Sampled       + Draw_Block_Ev       (Block_Read)     / A_Draw_Block         >= Drawing,
      Sampled       + Draw_Block_Ev                        / A_Refuse_Count       >= Sampled,
      Sampled       + Check_Runs_Ev       (Runs_Read)      / A_Check_Runs         >= Sampled,
      Sampled       + Check_Runs_Ev                        / A_Refuse_Check       >= Sampled,
      Sampled       + Check_Stratified    (Intervals_Read) / A_Check_Stratified   >= Sampled,
      Sampled       + Check_Stratified                     / A_Refuse_Check       >= Sampled,
      Sampled       + Check_Same_Seed     (Same_Read)      / A_Check_Same         >= Sampled,
      Sampled       + Check_Same_Seed                      / A_Refuse_Check       >= Sampled,
      Sampled       + Check_Other_Seed    (Seed_Read)      / A_Check_Other        >= Sampled,
      Sampled       + Check_Other_Seed                     / A_Refuse_Check       >= Sampled,
      Sampled       + Check_Block_Refused                  / A_Refuse_Filled      >= Sampled,
      Block_Refused + Check_Block_Refused (Refusal_Named)  / A_Check_Refused      >= Block_Refused,
      Block_Refused + Check_Block_Refused                  / A_Refuse_Check       >= Block_Refused];
   --!format on

   procedure Offer
     (Ctx : in out Step_Context; Evt : Step_Kind; Handled : out Boolean)
   is
      Current : Sampling_Stage := Ctx.W.Sobol.Stage;
   begin
      Flow.Take (Table, Current, Ctx, Evt, Handled);
      Ctx.W.Sobol.Stage := Current;
   end Offer;

   procedure Reset is null;

   function Phase return String
   is ("(in the scenario)");

end Abacus_Steps.Sobol;
