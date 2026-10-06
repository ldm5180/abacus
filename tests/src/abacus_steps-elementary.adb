with Ada.Characters.Handling;

with Abacus;            use Abacus;
with Abacus.Arith;      use Abacus.Arith;
with Abacus.Elementary; use Abacus.Elementary;
with Abacus.Text;

with Abacus_Steps.Flows;

package body Abacus_Steps.Elementary is

   --  Idle until a function is taken; Taken once a result is in hand.
   type State is (Idle, Taken);

   type Guard_Kind is
     (Always, Applicable, Applicable_Again, Square_Given, Within_Given);

   type Action_Kind is
     (A_Nothing,
      A_Apply,
      A_Apply_Again,
      A_Check_Square,
      A_Check_Within,
      A_Refuse_Apply,
      A_Refuse_Again,
      A_Refuse_Square,
      A_Refuse_Within,
      A_Refuse_Untaken);

   subtype Refuse_Action is
     Action_Kind range A_Refuse_Apply .. A_Refuse_Untaken;

   --  The functions a step may name.
   type Function_Name is (Root, Exp, Log, Cdf, Quantile);

   function Name_Said (Ctx : Step_Context) return String
   is (Ada.Characters.Handling.To_Lower (Fabula.Args.Word (Ctx.A, 1)));

   function Is_Function (Ctx : Step_Context) return Boolean
   is (for some F in Function_Name =>
         Ada.Characters.Handling.To_Lower (F'Image) = Name_Said (Ctx));

   function Named (Ctx : Step_Context) return Function_Name
   is (Function_Name'Value (Name_Said (Ctx)))
   with Pre => Is_Function (Ctx);

   --  Whether X is in the named function's domain.
   function In_Domain (F : Function_Name; X : Val) return Boolean
   is (case F is
         when Root     => X in Nonnegative,
         when Exp      => X in Exp_Arg,
         when Log      => X in Log_Arg,
         when Cdf      => True,
         when Quantile => X in Open_Probability);

   function Apply (F : Function_Name; X : Val) return Val
   is (case F is
         when Root     => Sqrt (X),
         when Exp      => Abacus.Elementary.Exp (X),
         when Log      => Abacus.Elementary.Log (X),
         when Cdf      => Norm_Cdf (X),
         when Quantile => Inv_Norm_Cdf (X))
   with Pre => In_Domain (F, X);

   function Evaluate
     (G : Guard_Kind; Ctx : Step_Context; Evt : Step_Kind) return Boolean
   is
      pragma Unreferenced (Evt);
   begin
      return
        (case G is
           when Always           => True,
           when Applicable       =>
             Is_Function (Ctx)
             and then Decimal_Read (Ctx, 2)
             and then In_Domain (Named (Ctx), Decimal_Of (Ctx, 2)),
           when Applicable_Again =>
             Is_Function (Ctx)
             and then In_Domain (Named (Ctx), Ctx.W.Elem.Value),
           when Square_Given     =>
             Decimal_Read (Ctx) and then Units_Read (Ctx, 2),
           when Within_Given     =>
             Decimal_Read (Ctx) and then Decimal_Read (Ctx, 2));
   end Evaluate;

   function Result (Ctx : Step_Context) return Val
   is (Ctx.W.Elem.Value);

   procedure Check_Near
     (Ctx : in out Step_Context; Got : Raw; Want, Slack : Raw) is
   begin
      Fabula.Check.Is_True
        (Ctx.R,
         abs (Got - Want) <= Slack,
         "the result is "
         & Abacus.Text.Image (Got)
         & ", off by"
         & Raw'Image (abs (Got - Want))
         & " units");
   end Check_Near;

   procedure Refuse (A : Refuse_Action; Ctx : in out Step_Context) is
      Domains : constant String :=
        ": root of a value at least 0, exp of one at most 11.75, log of"
        & " one above 0, cdf of any, quantile of one strictly between 0"
        & " and 1";
   begin
      case A is
         when A_Refuse_Apply   =>
            if Is_Function (Ctx) and then not Decimal_Read (Ctx, 2) then
               Refuse_Decimal (Ctx, 2);
            else
               Fabula.Check.Fail_Step
                 (Ctx.R, "cannot take the " & Name_Said (Ctx) & Domains);
            end if;

         when A_Refuse_Again   =>
            Fabula.Check.Fail_Step
              (Ctx.R,
               "cannot take the "
               & Name_Said (Ctx)
               & " of "
               & Abacus.Text.Image (Result (Ctx))
               & Domains);

         when A_Refuse_Square  =>
            Fabula.Check.Fail_Step
              (Ctx.R, "a square is checked against a number within units");

         when A_Refuse_Within  =>
            Fabula.Check.Fail_Step
              (Ctx.R, "a result is checked against a number within another");

         when A_Refuse_Untaken =>
            Fabula.Check.Fail_Step (Ctx.R, "no function has been taken");
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

         when A_Apply        =>
            Ctx.W.Elem.Value := Apply (Named (Ctx), Decimal_Of (Ctx, 2));

         when A_Apply_Again  =>
            Ctx.W.Elem.Value := Apply (Named (Ctx), Result (Ctx));

         when A_Check_Square =>
            Check_Near
              (Ctx,
               Mul_Sat (Result (Ctx), Result (Ctx)).Value,
               Decimal_Of (Ctx),
               Units_Of (Ctx, 2));

         when A_Check_Within =>
            Check_Near
              (Ctx, Result (Ctx), Decimal_Of (Ctx), Decimal_Of (Ctx, 2));

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

   Apply_Ev     : constant Ev := (Kind => E_Apply);
   Apply_Again  : constant Ev := (Kind => E_Apply_Again);
   Check_Square : constant Ev := (Kind => E_Check_Square);
   Check_Within : constant Ev := (Kind => E_Check_Within);

   --!format off
   Table : constant Transition_Table :=
     [Idle  + Apply_Ev     (Applicable)       / A_Apply          >= Taken,
      Idle  + Apply_Ev                        / A_Refuse_Apply   >= Idle,
      Idle  + Apply_Again                     / A_Refuse_Untaken >= Idle,
      Idle  + Check_Square                    / A_Refuse_Untaken >= Idle,
      Idle  + Check_Within                    / A_Refuse_Untaken >= Idle,
      Taken + Apply_Ev     (Applicable)       / A_Apply          >= Taken,
      Taken + Apply_Ev                        / A_Refuse_Apply   >= Taken,
      Taken + Apply_Again  (Applicable_Again) / A_Apply_Again    >= Taken,
      Taken + Apply_Again                     / A_Refuse_Again   >= Taken,
      Taken + Check_Square (Square_Given)     / A_Check_Square   >= Taken,
      Taken + Check_Square                    / A_Refuse_Square  >= Taken,
      Taken + Check_Within (Within_Given)     / A_Check_Within   >= Taken,
      Taken + Check_Within                    / A_Refuse_Within  >= Taken];
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

end Abacus_Steps.Elementary;
