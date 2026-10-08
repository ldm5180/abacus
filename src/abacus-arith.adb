package body Abacus.Arith
  with SPARK_Mode
is

   --  W held to -Bound .. Bound.
   function Within (W : Wide; Bound : Held) return Wide
   is (Wide'Max (-Bound, Wide'Min (Bound, W)))
   with Pre => Bound >= 0, Post => Within'Result in -Bound .. Bound;

   --  Where an upward shift starts each step from: a step of 2**30 then
   --  stays within Held_Bound.
   Before_Step : constant := Held_Bound / 2**Widest_Exponent;

   --  W times 2**E for E at least zero, held.
   function Shifted_Up (W : Product; E : Natural) return Held
   with Pre => E <= Power_Exponent'Last
   is
      R    : Wide := Within (W, Before_Step);
      Left : Natural := E;
      Step : Natural;
   begin
      while Left > 0 loop
         pragma Loop_Invariant (R in -Held_Bound .. Held_Bound);
         pragma Loop_Variant (Decreases => Left);
         Step := Natural'Min (Left, Widest_Exponent);
         R := Within (R, Before_Step) * Power_Of (Step);
         Left := Left - Step;
      end loop;
      return Within (R, Held_Bound);
   end Shifted_Up;

   --  W over 2**E for E at least zero, rounded at each step of 2**30.
   function Shifted_Down (W : Product; E : Natural) return Held
   with Pre => E <= Power_Exponent'Last
   is
      R    : Wide := W;
      Left : Natural := E;
      Step : Natural;
   begin
      while Left > 0 loop
         pragma Loop_Invariant (R in Product);
         pragma Loop_Variant (Decreases => Left);
         Step := Natural'Min (Left, Widest_Exponent);
         R := Div_Round (R, Power_Of (Step));
         Left := Left - Step;
      end loop;
      return Within (R, Held_Bound);
   end Shifted_Down;

   function Times_Power (W : Product; E : Power_Exponent) return Held
   is (if E >= 0 then Shifted_Up (W, E) else Shifted_Down (W, -E));

   procedure Store (W : Wide; V : in out Val; Ok : in out Boolean) is
   begin
      if Fits (W) then
         V := Val (W);
      else
         Ok := False;
      end if;
   end Store;

end Abacus.Arith;
