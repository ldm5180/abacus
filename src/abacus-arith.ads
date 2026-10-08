--  Products and quotients on the grid, each rounded once to nearest
--  with ties away from zero.  A result that might not fit is formed at
--  128 bits and either proved to fit (Mul, Div), saturated and reported
--  (Mul_Sat, Div_Sat), or narrowed through the checked Store.

package Abacus.Arith
  with SPARK_Mode, Pure
is

   --  What may be rounded: a sum of up to Max_N products of two values
   --  less a value raised to the scale One * One, with room for the
   --  rounding bias.
   Product_Bound : constant := 2**126 + 2**110;
   subtype Product is Wide range -Product_Bound .. Product_Bound;

   --  What a quotient may be divided by: a pivot, a count, a count times
   --  One, or a power of ten.
   Divisor_Bound : constant := 2**96;
   subtype Divisor is Wide range 1 .. Divisor_Bound;

   --  2**K for a shift, bounded by its element subtype so a product with
   --  it has a bound the prover can see.  Written out: the provers bound
   --  2**K for a variable K only so far.
   Widest_Shift : constant := 64;

   subtype Shift_Count is Natural range 0 .. Widest_Shift;
   subtype Power_Of_Two is Wide range 1 .. 2**Widest_Shift;

   --!format off
   Powers_Of_Two : constant array (Shift_Count) of Power_Of_Two :=
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
      576_460_752_303_423_488, 1_152_921_504_606_846_976,
      2_305_843_009_213_693_952, 4_611_686_018_427_387_904,
      9_223_372_036_854_775_808, 18_446_744_073_709_551_616];
   --!format on

   --  N / D rounded to nearest, ties away from zero: the one rounding
   --  every operation here takes.
   function Div_Round (N : Product; D : Divisor) return Wide
   is (if N >= 0 then (N + D / 2) / D else -((-N + D / 2) / D))
   with
     Post =>
       (if N >= 0
        then Div_Round'Result in 0 .. N
        else Div_Round'Result in N .. 0);

   --  A value at scale One * One brought to scale One.
   Shifted_Bound : constant := Product_Bound / One + 1;

   function Round_Shift (A : Product) return Wide
   is (Div_Round (A, One))
   with Post => Round_Shift'Result in -Shifted_Bound .. Shifted_Bound;

   --  Whether a wide result can be stored as a value.
   function Fits (W : Wide) return Boolean
   is (W in Wide (Val'First) .. Wide (Val'Last));

   --  A times B, rounded once to the grid.
   function Product_Of (A, B : Val) return Wide
   is (Round_Shift (Wide (A) * Wide (B)));

   --  A over B, rounded once to the grid.
   function Quotient_Of (A, B : Val) return Wide
   is (if B > 0
       then Div_Round (Wide (A) * One, Wide (B))
       else Div_Round (-(Wide (A) * One), -Wide (B)))
   with Pre => B /= 0;

   --  A times B, where the caller has shown that the product fits.
   function Mul (A, B : Val) return Val
   is (Val (Product_Of (A, B)))
   with Pre => Fits (Product_Of (A, B));

   --  A over B, where the caller has shown that the quotient fits.
   function Div (A, B : Val) return Val
   is (Val (Quotient_Of (A, B)))
   with Pre => B /= 0 and then Fits (Quotient_Of (A, B));

   --  An exponent of two a step size is taken at.
   Widest_Exponent : constant := 30;
   subtype Exponent is Integer range -Widest_Exponent .. Widest_Exponent;

   --  2**S for an exponent's magnitude, its subtype the bound a product
   --  with it needs.
   subtype Exponent_Power is Wide range 1 .. 2**Widest_Exponent;
   function Power_Of (S : Natural) return Exponent_Power
   is (Powers_Of_Two (S))
   with Pre => S <= Widest_Exponent;

   --  The magnitude V * 2**S may reach.
   Scaled_Bound : constant := Val_Bound * 2**Widest_Exponent;

   --  V times 2**S, rounded half away from zero when S is negative.
   function Scaled (V : Val; S : Exponent) return Wide
   is (if S >= 0
       then Wide (V) * Power_Of (S)
       else Div_Round (Wide (V), Power_Of (-S)))
   with Post => Scaled'Result in -Scaled_Bound .. Scaled_Bound;

   --  W held to Lo .. Hi.
   function Clamp (W : Wide; Lo, Hi : Val) return Val
   is (if W <= Wide (Lo) then Lo elsif W >= Wide (Hi) then Hi else Val (W))
   with Pre => Lo <= Hi, Post => Clamp'Result in Lo .. Hi;

   --  How a saturating operation ended: in range, held at the largest
   --  value of its sign, or a quotient by zero.
   type Status is (Ok, Saturated, Undefined);

   type Checked is record
      Value  : Val := 0;
      Status : Arith.Status := Ok;
   end record;

   --  W held to the values, and whether it had to be.
   function Saturate (W : Wide) return Checked
   is ((Value  =>
          (if W > Wide (Val'Last)
           then Val'Last
           elsif W < Wide (Val'First)
           then Val'First
           else Val (W)),
        Status => (if Fits (W) then Ok else Saturated)));

   --  A times B, saturated inside the 128-bit product.
   function Mul_Sat (A, B : Val) return Checked
   is (Saturate (Product_Of (A, B)));

   --  A over B, saturated inside the 128-bit quotient; Undefined, with a
   --  value of zero, when B is zero.
   function Div_Sat (A, B : Val) return Checked
   is (if B = 0
       then (Value => 0, Status => Undefined)
       else Saturate (Quotient_Of (A, B)));

   --  W stored into V when it fits; Ok cleared, and V left as it was,
   --  when it does not.  Every narrowing in the library goes through it.
   procedure Store (W : Wide; V : in out Val; Ok : in out Boolean)
   with
     Post =>
       (if Fits (W)
        then Wide (V) = W and then Ok = Ok'Old
        else not Ok and then V = V'Old);

end Abacus.Arith;
