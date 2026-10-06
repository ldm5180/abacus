with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

with Fabula.Numbers;

with Abacus_Steps.Arithmetic;
with Abacus_Steps.Text;

package body Abacus_Steps is

   use type Abacus.Raw;

   procedure Then_Take (Ctx : in out Step_Context; Evt : Step_Kind) is
   begin
      Ctx.Has_Next := True;
      Ctx.Next := Evt;
   end Then_Take;

   function Units_Read (Ctx : Step_Context; N : Positive := 1) return Boolean
   is (N <= Fabula.Args.Count (Ctx.A) and then Fabula.Args.Long (Ctx.A, N).Ok);

   function Units_Of (Ctx : Step_Context; N : Positive := 1) return Abacus.Raw
   is (Abacus.Raw (Fabula.Args.Long (Ctx.A, N).Value));

   procedure Refuse_Units (Ctx : in out Step_Context; N : Positive := 1) is
      Error : Fabula.Numbers.Read_Error := Fabula.Numbers.Malformed;
   begin
      if N <= Fabula.Args.Count (Ctx.A) then
         Error := Fabula.Args.Long (Ctx.A, N).Error;
      end if;
      Fabula.Check.Fail_Step
        (Ctx.R,
         "capture"
         & N'Image
         & " is not a whole number of units: "
         & Fabula.Numbers.Reason (Error));
   end Refuse_Units;

   --  The largest whole number a value holds.
   Whole_Bound : constant := Abacus.Val_Bound / Abacus.One;

   function Whole_Read (Ctx : Step_Context; N : Positive := 1) return Boolean
   is (Units_Read (Ctx, N) and then abs Units_Of (Ctx, N) <= Whole_Bound);

   procedure Refuse_Whole (Ctx : in out Step_Context; N : Positive := 1) is
   begin
      if Units_Read (Ctx, N) then
         Fabula.Check.Fail_Step
           (Ctx.R, "a whole value is at most" & Whole_Bound'Image);
      else
         Refuse_Units (Ctx, N);
      end if;
   end Refuse_Whole;

   function Ratio_Read (Ctx : Step_Context; N : Positive := 1) return Boolean
   is (Whole_Read (Ctx, N)
       and then Whole_Read (Ctx, N + 1)
       and then Units_Of (Ctx, N + 1) /= 0);

   function Ratio_Of (Ctx : Step_Context; N : Positive := 1) return Abacus.Val
   is (Abacus.Arith.Div
         (Units_Of (Ctx, N) * Abacus.One, Units_Of (Ctx, N + 1) * Abacus.One));

   procedure Refuse_Ratio (Ctx : in out Step_Context; N : Positive := 1) is
   begin
      if not Units_Read (Ctx, N) then
         Refuse_Units (Ctx, N);
      elsif not Units_Read (Ctx, N + 1) then
         Refuse_Units (Ctx, N + 1);
      else
         Fabula.Check.Fail_Step
           (Ctx.R,
            "a fraction needs whole parts of at most"
            & Whole_Bound'Image
            & " and a denominator that is not zero");
      end if;
   end Refuse_Ratio;

   ---------------------------------------------------------------------
   --  The features as orthogonal regions: every step is offered to each,
   --  and each takes only its own.
   ---------------------------------------------------------------------

   type Offer_Access is
     access procedure
       (Ctx : in out Step_Context; Evt : Step_Kind; Handled : out Boolean);
   type Reset_Access is access procedure;
   type Phase_Access is access function return String;
   type Name_Access is access constant String;

   type Region is record
      Name  : Name_Access;
      Offer : Offer_Access;
      Reset : Reset_Access;
      Phase : Phase_Access;
   end record;

   Arithmetic_Name : aliased constant String := "arithmetic";
   Text_Name       : aliased constant String := "text";

   --!format off
   Regions : constant array (Positive range <>) of Region :=
     [(Arithmetic_Name'Access, Arithmetic.Offer'Access,
       Arithmetic.Reset'Access, Arithmetic.Phase'Access),
      (Text_Name'Access, Text.Offer'Access,
       Text.Reset'Access, Text.Phase'Access)];
   --!format on

   --  Every region's state, for the step no region would take.
   function Phases return String is
      Text : Unbounded_String;
   begin
      for G of Regions loop
         Append (Text, " " & G.Name.all & "=" & G.Phase.all);
      end loop;
      return To_String (Text);
   end Phases;

   procedure Execute
     (S    : Step_Kind;
      Ctx  : in out World;
      A    : Fabula.Args.List;
      Info : Fabula.Frames.Frame;
      R    : in out Fabula.Check.Outcome)
   is
      Step    : Step_Context :=
        (W => Ctx, A => A, Info => Info, R => R, others => <>);
      Taken   : Boolean := False;
      Handled : Boolean;
   begin
      for G of Regions loop
         G.Offer (Step, S, Handled);
         Taken := Taken or else Handled;
      end loop;
      Ctx := Step.W;
      R := Step.R;
      if not Taken then
         Fabula.Check.Fail_Step
           (R,
            S'Image & " is not a step this scenario can take now:" & Phases);
      end if;
   end Execute;

   procedure Run_Hook
     (H    : Hook_Kind;
      Ctx  : in out World;
      Info : Fabula.Frames.Frame;
      R    : in out Fabula.Check.Outcome)
   is
      pragma Unreferenced (Info, R);
   begin
      case H is
         when Fresh_World =>
            Ctx := (others => <>);
            for G of Regions loop
               G.Reset.all;
            end loop;
      end case;
   end Run_Hook;

end Abacus_Steps;
