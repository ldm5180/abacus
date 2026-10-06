with Abacus.Arith;

package body Abacus.Ieee
  with SPARK_Mode
is

   --  A pattern widened, so every field is taken out by Wide arithmetic.
   subtype Pattern is Wide range 0 .. 2**64 - 1;

   --  The widest fraction field read, binary64's.
   Widest_Fraction : constant := 52;

   subtype Significand is Wide range 0 .. 2**(Widest_Fraction + 1) - 1;

   --  Where a finite number's units lie relative to its significand.
   subtype Power_Range is Integer range -2**11 .. 2**11;

   --  A pattern taken apart: its sign; whether its exponent is all
   --  ones (an infinity or a NaN); its significand, with the hidden bit
   --  when the number is normal; and the power of two that puts the
   --  significand on the grid, units = significand * 2**power.
   type Parts is record
      Negative    : Boolean;
      Special     : Boolean;
      Significand : Abacus.Ieee.Significand;
      Power       : Power_Range;
   end record;

   --  A layout: its fraction field's span (2**fraction bits, also the
   --  hidden bit), its exponent field's span (2**exponent bits), and
   --  what is taken from a stored exponent to place the significand on
   --  the grid (the bias plus the fraction bits less Frac).
   type Layout is record
      Hidden    : Wide range 1 .. 2**Widest_Fraction;
      Exponents : Wide range 2 .. 2**11;
      Offset    : Natural range 0 .. 2**11;
   end record;

   Binary64 : constant Layout := (2**52, 2**11, 1_023 + 52 - Frac);
   Binary32 : constant Layout := (2**23, 2**8, 127 + 23 - Frac);

   function Split (Bits : Pattern; L : Layout) return Parts is
      Fraction : constant Wide := Bits mod L.Hidden;
      Exponent : constant Wide := (Bits / L.Hidden) mod L.Exponents;
   begin
      return
        (Negative    => (Bits / L.Hidden / L.Exponents) mod 2 = 1,
         Special     => Exponent = L.Exponents - 1,
         Significand =>
           Fraction
           + (if Exponent in 1 .. L.Exponents - 2 then L.Hidden else 0),
         Power       => Integer (Wide'Max (Exponent, 1)) - L.Offset);
   end Split;

   --  How far a significand is shifted up before it is surely past the
   --  values, and down before it is surely under half a unit.
   Max_Up   : constant := 34;
   Max_Down : constant := 60;

   function Refusal (O : Outcome) return Read
   is ((Outcome => O, Value => 0));

   --  S times 2**Power, rounded to the grid, as a read.
   function Scaled
     (S : Significand; Power : Integer; Negative : Boolean) return Read
   with Post => Scaled'Result.Outcome = Ok or else Scaled'Result.Value = 0
   is
      Units : Wide := 0;
   begin
      if Power > Max_Up then
         return Refusal (Out_Of_Range);
      elsif Power >= 0 then
         Units := S * Arith.Powers_Of_Two (Power);
      elsif Power >= -Max_Down then
         Units := Arith.Div_Round (S, Arith.Powers_Of_Two (-Power));
      end if;
      if Units > Val_Bound then
         return Refusal (Out_Of_Range);
      end if;
      return (Ok, Val (if Negative then -Units else Units));
   end Scaled;

   --  The exponent's all-ones value marks an infinity, when the fraction
   --  is zero, or a NaN.  A special number's significand is its fraction.
   function Classify (P : Parts) return Read
   is (if not P.Special
       then Scaled (P.Significand, P.Power, P.Negative)
       elsif P.Significand = 0
       then Refusal (Infinite)
       else Refusal (Not_A_Number))
   with Post => Classify'Result.Outcome = Ok or else Classify'Result.Value = 0;

   function From_Binary64 (Bits : Interfaces.Unsigned_64) return Read
   is (Classify (Split (Pattern (Bits), Binary64)));

   function From_Binary32 (Bits : Interfaces.Unsigned_32) return Read
   is (Classify (Split (Pattern (Bits), Binary32)));

end Abacus.Ieee;
