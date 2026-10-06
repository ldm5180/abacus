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

   --  2**K, bounded by its element subtype so the prover sees the bound.
   subtype Power_Of_Two is Wide range 1 .. 2**Max_Down;

   subtype Shift_Count is Natural range 0 .. Max_Down;

   --  Written out: the provers bound 2**K for a variable K only so far.
   --!format off
   Powers : constant array (Shift_Count) of Power_Of_Two :=
     [1, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1_024, 2_048, 4_096, 8_192,
      16_384, 32_768, 65_536, 131_072, 262_144, 524_288, 1_048_576,
      2_097_152, 4_194_304, 8_388_608, 16_777_216, 33_554_432, 67_108_864,
      134_217_728, 268_435_456, 536_870_912, 1_073_741_824, 2_147_483_648,
      4_294_967_296, 8_589_934_592, 17_179_869_184, 34_359_738_368,
      68_719_476_736, 137_438_953_472, 274_877_906_944, 549_755_813_888,
      1_099_511_627_776, 2_199_023_255_552, 4_398_046_511_104,
      8_796_093_022_208, 17_592_186_044_416, 35_184_372_088_832,
      70_368_744_177_664, 140_737_488_355_328, 281_474_976_710_656,
      562_949_953_421_312, 1_125_899_906_842_624, 2_251_799_813_685_248,
      4_503_599_627_370_496, 9_007_199_254_740_992, 18_014_398_509_481_984,
      36_028_797_018_963_968, 72_057_594_037_927_936,
      144_115_188_075_855_872, 288_230_376_151_711_744,
      576_460_752_303_423_488, 1_152_921_504_606_846_976];
   --!format on

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
         Units := S * Powers (Power);
      elsif Power >= -Max_Down then
         Units := Arith.Div_Round (S, Powers (-Power));
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
