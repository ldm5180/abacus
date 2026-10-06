with Abacus; use Abacus;

with Abacus_Steps.Flows;

package body Abacus_Steps.Arithmetic is

   --  Idle until operands are given.
   type State is (Idle);

   type Guard_Kind is (Always, Units_Given);

   type Action_Kind is (A_Nothing, A_Check_One, A_Refuse_Units);

   function Evaluate
     (G : Guard_Kind; Ctx : Step_Context; Evt : Step_Kind) return Boolean
   is
      pragma Unreferenced (Evt);
   begin
      return
        (case G is
           when Always      => True,
           when Units_Given => Units_Read (Ctx));
   end Evaluate;

   procedure Execute
     (A : Action_Kind; Ctx : in out Step_Context; Evt : Step_Kind)
   is
      pragma Unreferenced (Evt);
   begin
      case A is
         when A_Nothing      =>
            null;

         when A_Check_One    =>
            Fabula.Check.Is_True
              (Ctx.R,
               Raw (One) = Units_Of (Ctx),
               "one is" & Raw'Image (One) & " units");

         when A_Refuse_Units =>
            Refuse_Units (Ctx);
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

   Check_One : constant Ev := (Kind => E_Check_One);

   --!format off
   Table : constant Transition_Table :=
     [Idle + Check_One (Units_Given) / A_Check_One    >= Idle,
      Idle + Check_One               / A_Refuse_Units >= Idle];
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
