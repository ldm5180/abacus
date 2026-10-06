with Ada.Characters.Handling;

with Abacus;       use Abacus;
with Abacus.Arith; use Abacus.Arith;

with Abacus_Steps.Flows;

package body Abacus_Steps.Arithmetic is

   --  Idle until an operand is given; Holding while operands are given;
   --  Computed once they are combined, when the result can be checked.
   type State is (Idle, Holding, Computed);

   type Guard_Kind is
     (Always,
      Units_Given,
      Units_Operand,
      Whole_Operand,
      Ratio_Operand,
      Both_Given,
      Ratio_Given,
      Status_Named,
      Extreme_Named);

   type Action_Kind is
     (A_Nothing,
      A_Give_Units,
      A_Give_Whole,
      A_Give_Ratio,
      A_Multiply,
      A_Divide,
      A_Check_One,
      A_Check_Units,
      A_Check_Ratio,
      A_Check_Status,
      A_Check_Extreme,
      A_Refuse_Units,
      A_Refuse_Units_Operand,
      A_Refuse_Whole_Operand,
      A_Refuse_Operand,
      A_Refuse_Missing,
      A_Refuse_Ratio,
      A_Refuse_Status,
      A_Refuse_Extreme);

   subtype Give_Action is Action_Kind range A_Give_Units .. A_Divide;
   subtype Check_Action is Action_Kind range A_Check_One .. A_Check_Extreme;
   subtype Refuse_Action is
     Action_Kind range A_Refuse_Units .. A_Refuse_Extreme;

   Name_Arg : constant := 1;

   function Lower (S : String) return String
   renames Ada.Characters.Handling.To_Lower;

   function Word_Of (Ctx : Step_Context; N : Positive) return String
   is (Lower (Fabula.Args.Word (Ctx.A, N)));

   function Is_Operand (Ctx : Step_Context; N : Positive) return Boolean
   is (for some O in Operand => Lower (O'Image) = Word_Of (Ctx, N));

   function Operand_Of (Ctx : Step_Context; N : Positive) return Operand
   is (if Word_Of (Ctx, N) = "a" then A else B)
   with Pre => Is_Operand (Ctx, N);

   function Is_Status (Ctx : Step_Context) return Boolean
   is (for some S in Status => Lower (S'Image) = Word_Of (Ctx, 1));

   function Is_Extreme (Ctx : Step_Context) return Boolean
   is (Word_Of (Ctx, 1) in "largest" | "smallest");

   --  The two operands a combining step names, both given.
   function Both (Ctx : Step_Context) return Boolean
   is (Is_Operand (Ctx, 1)
       and then Is_Operand (Ctx, 2)
       and then Ctx.W.Arith.Given (Operand_Of (Ctx, 1))
       and then Ctx.W.Arith.Given (Operand_Of (Ctx, 2)));

   function Evaluate
     (G : Guard_Kind; Ctx : Step_Context; Evt : Step_Kind) return Boolean
   is
      pragma Unreferenced (Evt);
   begin
      return
        (case G is
           when Always        => True,
           when Units_Given   => Units_Read (Ctx),
           when Units_Operand =>
             Is_Operand (Ctx, Name_Arg)
             and then Units_Read (Ctx, 2)
             and then Units_Of (Ctx, 2) in Val,
           when Whole_Operand =>
             Is_Operand (Ctx, Name_Arg) and then Whole_Read (Ctx, 2),
           when Ratio_Operand =>
             Is_Operand (Ctx, Name_Arg) and then Ratio_Read (Ctx, 2),
           when Both_Given    => Both (Ctx),
           when Ratio_Given   => Ratio_Read (Ctx),
           when Status_Named  => Is_Status (Ctx),
           when Extreme_Named => Is_Extreme (Ctx));
   end Evaluate;

   procedure Give (Ctx : in out Step_Context; V : Val) is
      O : constant Operand := Operand_Of (Ctx, Name_Arg);
   begin
      Ctx.W.Arith.Value (O) := V;
      Ctx.W.Arith.Given (O) := True;
   end Give;

   --  What an operand step is given, for the reason it was refused.
   type Given_Kind is (Units, Whole, Ratio);

   procedure Refuse_Operand (Ctx : in out Step_Context; Kind : Given_Kind) is
   begin
      if not Is_Operand (Ctx, Name_Arg) then
         Fabula.Check.Fail_Step
           (Ctx.R, "no operand named " & Word_Of (Ctx, Name_Arg) & ": a or b");
      else
         case Kind is
            when Units =>
               Refuse_Units (Ctx, 2);

            when Whole =>
               Refuse_Whole (Ctx, 2);

            when Ratio =>
               Refuse_Ratio (Ctx, 2);
         end case;
      end if;
   end Refuse_Operand;

   --  The operands a combining step names, in its order.
   function Left (Ctx : Step_Context) return Val
   is (Ctx.W.Arith.Value (Operand_Of (Ctx, 1)))
   with Pre => Is_Operand (Ctx, 1);

   function Right (Ctx : Step_Context) return Val
   is (Ctx.W.Arith.Value (Operand_Of (Ctx, 2)))
   with Pre => Is_Operand (Ctx, 2);

   procedure Check_Value (Ctx : in out Step_Context; Want : Val) is
   begin
      Fabula.Check.Is_True
        (Ctx.R,
         Ctx.W.Arith.Result = (Want, Ok),
         "the result is"
         & Ctx.W.Arith.Result.Value'Image
         & " units, "
         & Ctx.W.Arith.Result.Status'Image
         & "; want"
         & Want'Image);
   end Check_Value;

   function Extreme_Wanted (Ctx : Step_Context) return Val
   is (if Word_Of (Ctx, 1) = "largest" then Val'Last else Val'First);

   --  The steps that give operands or combine them.
   procedure Give (A : Give_Action; Ctx : in out Step_Context) is
   begin
      case A is
         when A_Give_Units =>
            Give (Ctx, Units_Of (Ctx, 2));

         when A_Give_Whole =>
            Give (Ctx, Units_Of (Ctx, 2) * One);

         when A_Give_Ratio =>
            Give (Ctx, Ratio_Of (Ctx, 2));

         when A_Multiply   =>
            Ctx.W.Arith.Result := Mul_Sat (Left (Ctx), Right (Ctx));

         when A_Divide     =>
            Ctx.W.Arith.Result := Div_Sat (Left (Ctx), Right (Ctx));
      end case;
   end Give;

   procedure Check (A : Check_Action; Ctx : in out Step_Context) is
      Result : constant Checked := Ctx.W.Arith.Result;
   begin
      case A is
         when A_Check_One     =>
            Fabula.Check.Is_True
              (Ctx.R,
               Raw (One) = Units_Of (Ctx),
               "one is" & Raw'Image (One) & " units");

         when A_Check_Units   =>
            Check_Value (Ctx, Units_Of (Ctx));

         when A_Check_Ratio   =>
            Check_Value (Ctx, Ratio_Of (Ctx));

         when A_Check_Status  =>
            Fabula.Check.Text_Equal
              (Ctx.R,
               Lower (Result.Status'Image),
               Word_Of (Ctx, 1),
               "the result's status");

         when A_Check_Extreme =>
            Fabula.Check.Is_True
              (Ctx.R,
               Result.Value = Extreme_Wanted (Ctx),
               "the result is" & Result.Value'Image & " units");
      end case;
   end Check;

   procedure Refuse (A : Refuse_Action; Ctx : in out Step_Context) is
   begin
      case A is
         when A_Refuse_Units         =>
            Refuse_Units (Ctx);

         when A_Refuse_Units_Operand =>
            Refuse_Operand (Ctx, Units);

         when A_Refuse_Whole_Operand =>
            Refuse_Operand (Ctx, Whole);

         when A_Refuse_Operand       =>
            Refuse_Operand (Ctx, Ratio);

         when A_Refuse_Missing       =>
            Fabula.Check.Fail_Step
              (Ctx.R, "both operands must be named a or b, and given first");

         when A_Refuse_Ratio         =>
            Refuse_Ratio (Ctx);

         when A_Refuse_Status        =>
            Fabula.Check.Fail_Step
              (Ctx.R,
               "no status named "
               & Word_Of (Ctx, 1)
               & ": ok, saturated or undefined");

         when A_Refuse_Extreme       =>
            Fabula.Check.Fail_Step
              (Ctx.R,
               "no value named the "
               & Word_Of (Ctx, 1)
               & ": the largest or the smallest");
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

         when Give_Action   =>
            Give (A, Ctx);

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

   Check_One     : constant Ev := (Kind => E_Check_One);
   Give_Units    : constant Ev := (Kind => E_Give_Units);
   Give_Whole    : constant Ev := (Kind => E_Give_Whole);
   Give_Ratio    : constant Ev := (Kind => E_Give_Ratio);
   Multiply      : constant Ev := (Kind => E_Multiply);
   Divide        : constant Ev := (Kind => E_Divide);
   Check_Units   : constant Ev := (Kind => E_Check_Units);
   Check_Ratio   : constant Ev := (Kind => E_Check_Ratio);
   Check_Status  : constant Ev := (Kind => E_Check_Status);
   Check_Extreme : constant Ev := (Kind => E_Check_Extreme);

   --!format off
   Table : constant Transition_Table :=
     [Idle     + Check_One     (Units_Given)   / A_Check_One      >= Idle,
      Idle     + Check_One                     / A_Refuse_Units   >= Idle,
      Idle     + Give_Units    (Units_Operand) / A_Give_Units     >= Holding,
      Idle     + Give_Units                    / A_Refuse_Units_Operand >= Idle,
      Idle     + Give_Whole    (Whole_Operand) / A_Give_Whole     >= Holding,
      Idle     + Give_Whole                    / A_Refuse_Whole_Operand >= Idle,
      Idle     + Give_Ratio    (Ratio_Operand) / A_Give_Ratio     >= Holding,
      Idle     + Give_Ratio                    / A_Refuse_Operand >= Idle,
      Holding  + Give_Units    (Units_Operand) / A_Give_Units     >= Holding,
      Holding  + Give_Units                    / A_Refuse_Units_Operand >= Holding,
      Holding  + Give_Whole    (Whole_Operand) / A_Give_Whole     >= Holding,
      Holding  + Give_Whole                    / A_Refuse_Whole_Operand >= Holding,
      Holding  + Give_Ratio    (Ratio_Operand) / A_Give_Ratio     >= Holding,
      Holding  + Give_Ratio                    / A_Refuse_Operand >= Holding,
      Holding  + Multiply      (Both_Given)    / A_Multiply       >= Computed,
      Holding  + Multiply                      / A_Refuse_Missing >= Holding,
      Holding  + Divide        (Both_Given)    / A_Divide         >= Computed,
      Holding  + Divide                        / A_Refuse_Missing >= Holding,
      Computed + Multiply      (Both_Given)    / A_Multiply       >= Computed,
      Computed + Multiply                      / A_Refuse_Missing >= Computed,
      Computed + Divide        (Both_Given)    / A_Divide         >= Computed,
      Computed + Divide                        / A_Refuse_Missing >= Computed,
      Computed + Check_Units   (Units_Given)   / A_Check_Units    >= Computed,
      Computed + Check_Units                   / A_Refuse_Units   >= Computed,
      Computed + Check_Ratio   (Ratio_Given)   / A_Check_Ratio    >= Computed,
      Computed + Check_Ratio                   / A_Refuse_Ratio   >= Computed,
      Computed + Check_Status  (Status_Named)  / A_Check_Status   >= Computed,
      Computed + Check_Status                  / A_Refuse_Status  >= Computed,
      Computed + Check_Extreme (Extreme_Named) / A_Check_Extreme  >= Computed,
      Computed + Check_Extreme                 / A_Refuse_Extreme >= Computed];
   --!format on

   Current : State := Idle;

   procedure Offer
     (Ctx : in out Step_Context; Evt : Step_Kind; Handled : out Boolean) is
   begin
      Flow.Take (Table, Current, Ctx, Evt, Handled);
   end Offer;

   procedure Reset is
   begin
      Current := Idle;
   end Reset;

   function Phase return String
   is (Current'Image);

end Abacus_Steps.Arithmetic;
