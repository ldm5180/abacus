with Abacus.Arith; use Abacus.Arith;

package body Abacus.Elementary
  with SPARK_Mode
is

   ---------------------------------------------------------------------
   --  Roots.
   ---------------------------------------------------------------------

   --  Bit by bit from 2**56 down: R is the largest integer whose square
   --  is at most X, then one comparison rounds it to nearest.  R stays
   --  under 2**57 because its square is under 2**114; the clamp on the
   --  rounded result states that without a nonlinear proof.
   function Root (X : Root_Arg) return Val is
      R    : Wide := 0;
      Step : Wide := 2**(Val_Bits - 1);
   begin
      for B in 0 .. Val_Bits - 1 loop
         if (R + Step) * (R + Step) <= X then
            R := R + Step;
         end if;
         Step := Step / 2;
         pragma
           Loop_Invariant
             (R >= 0 and then Step >= 0 and then R + 2 * Step <= Val_Bound);
         pragma Loop_Invariant (R * R <= X);
      end loop;
      return Val (Wide'Min ((if X - R * R > R then R + 1 else R), Val_Bound));
   end Root;

   function Sqrt (X : Nonnegative) return Nonnegative
   is (Root (Wide (X) * One));

   ---------------------------------------------------------------------
   --  Fine arithmetic: Exp and Log work at 2**-60 and round once.
   ---------------------------------------------------------------------

   Fine_Frac : constant := 60;
   Fine_One  : constant := 2**Fine_Frac;

   --  A value at a fine scale (2**-60, or 2**-52 for the quantile's
   --  tails): at most 2**62 raw, so a product of two is under 2**124.
   Fine_Bound : constant := 2**62;
   subtype Fine is Wide range -Fine_Bound .. Fine_Bound;

   --  The fine scales used, as shifts.
   subtype Fine_Shift is Natural range Frac .. Fine_Frac;

   function Clamp (W : Wide; Bound : Wide) return Wide
   is (if W > Bound then Bound elsif W < -Bound then -Bound else W)
   with Pre => Bound >= 0, Post => Clamp'Result in -Bound .. Bound;

   --  A times B at the scale 2**-S, rounded once, held to the fine
   --  values (the clamp never binds where it is used: it states the
   --  bound).
   function Fine_Mul (A, B : Fine; S : Fine_Shift := Fine_Frac) return Fine
   is (Clamp (Div_Round (A * B, Powers_Of_Two (S)), Fine_Bound));

   type Fine_Coefficients is array (Natural range <>) of Fine;

   --  C (0) + X (C (1) + X (C (2) + ...)), each stage at the scale
   --  2**-S.
   function Fine_Horner
     (C : Fine_Coefficients; X : Fine; S : Fine_Shift := Fine_Frac) return Fine
   is
      Acc : Fine := 0;
   begin
      for K in reverse C'Range loop
         Acc := Clamp (C (K) + Fine_Mul (X, Acc, S), Fine_Bound);
      end loop;
      return Acc;
   end Fine_Horner;

   --  A fine value brought to the grid.
   function To_Grid (F : Product) return Wide
   is (Div_Round (F, 2**(Fine_Frac - Frac)));

   ---------------------------------------------------------------------
   --  Exp: x = m ln 2 / 16 + r with r in [0, ln 2 / 16), so
   --  exp x = 2**(m div 16) * 2**((m mod 16) / 16) * exp r.
   ---------------------------------------------------------------------

   --  16 / ln 2 on the grid, and ln 2 / 16 at the fine scale.
   Inv_Ln2_16  : constant := 25_380_159_564_675;
   Fine_Ln2_16 : constant := 49_946_518_145_322_874;

   --!format off
   --  2**(J / 16), fine.
   Two_To_Sixteenths : constant Fine_Coefficients (0 .. 15) :=
     [1_152_921_504_606_846_976, 1_203_965_700_457_697_123,
      1_257_269_815_929_830_109, 1_312_933_906_212_862_055,
      1_371_062_456_318_104_878, 1_431_764_577_203_528_246,
      1_495_154_210_581_915_421, 1_561_350_342_796_650_841,
      1_630_477_228_166_597_777, 1_702_664_622_219_298_520,
      1_778_048_025_250_290_524, 1_856_768_936_665_714_716,
      1_938_975_120_585_633_119, 2_024_820_883_206_609_954,
      2_114_467_362_444_183_334, 2_208_082_830_398_904_710];

   --  1 / K!, fine: exp r's series, past the fine grid at r < 0.0434.
   Inverse_Factorials : constant Fine_Coefficients (0 .. 8) :=
     [1_152_921_504_606_846_976, 1_152_921_504_606_846_976,
      576_460_752_303_423_488, 192_153_584_101_141_163,
      48_038_396_025_285_291, 9_607_679_205_057_058,
      1_601_279_867_509_510, 228_754_266_787_073, 28_594_283_348_384];
   --!format on

   --  The sixteenths of ln 2 in X, rounded down; X is above Exp_Floor.
   subtype Sixteenths is Wide range -1_024 .. 1_024;

   function Sixteenths_In (X : Exp_Arg) return Sixteenths
   with Pre => X >= Exp_Floor
   is
      Y : constant Wide := Product_Of (X, Inv_Ln2_16);
   begin
      return
        Clamp
          ((if Y >= 0 then Y / One else -((-Y + One - 1) / One)),
           Sixteenths'Last);
   end Sixteenths_In;

   --  The fine value 2**((M mod 16) / 16) * exp (X - M ln 2 / 16).
   function Mantissa (X : Exp_Arg; M : Sixteenths) return Fine
   with Pre => X >= Exp_Floor
   is
      R : constant Fine :=
        Clamp (Wide (X) * 2**(Fine_Frac - Frac) - M * Fine_Ln2_16, Fine_One);
   begin
      return
        Fine_Mul
          (Two_To_Sixteenths (Natural (M mod 16)),
           Fine_Horner (Inverse_Factorials, R));
   end Mantissa;

   --  The fine mantissa times 2**E, on the grid, held to the values.
   function Placed (Mant : Fine; E : Wide) return Nonnegative
   with Pre => E in -Sixteenths'Last .. Sixteenths'Last
   is
      Down : constant Wide := Fine_Frac - Frac - E;
      Grid : Wide;
   begin
      if Down > Wide (Widest_Shift) then
         return 0;
      elsif Down >= 0 then
         Grid := Div_Round (Mant, Powers_Of_Two (Natural (Down)));
      else
         Grid := Mant * Powers_Of_Two (Natural (Wide'Min (-Down, Val_Bits)));
      end if;
      return Val (Wide'Max (0, Wide'Min (Grid, Val_Bound)));
   end Placed;

   function Exp (X : Exp_Arg) return Nonnegative is
      M : Sixteenths;
   begin
      if X < Exp_Floor then
         return 0;
      end if;
      M := Sixteenths_In (X);
      return Placed (Mantissa (X, M), (M - M mod 16) / 16);
   end Exp;

   ---------------------------------------------------------------------
   --  Log: x = 2**k * m with m in [1, 2); m = (1 + j / 16) * u with u
   --  within a sixteenth of one; log x = k ln 2 + log (1 + j / 16) +
   --  2 atanh ((u - 1) / (u + 1)).
   ---------------------------------------------------------------------

   Fine_Ln2 : constant := 799_144_290_325_165_979;

   --!format off
   --  log (1 + J / 16) and 1 / (1 + J / 16), fine.
   Log_Sixteenths : constant Fine_Coefficients (0 .. 15) :=
     [0,                       69_895_430_200_825_139,
      135_794_594_686_119_519, 198_129_856_782_957_177,
      257_266_998_924_493_878, 313_518_228_408_730_497,
      367_152_154_828_845_215, 418_401_547_814_437_287,
      467_469_442_505_642_749, 514_533_997_848_987_755,
      559_752_401_469_422_381, 603_264_037_191_762_267,
      645_193_076_228_253_727, 685_650_613_463_703_312,
      724_736_441_430_136_626, 762_540_533_295_011_191];

   Inverse_Sixteenths : constant Fine_Coefficients (0 .. 15) :=
     [1_152_921_504_606_846_976, 1_085_102_592_571_150_095,
      1_024_819_115_206_086_201,   970_881_267_037_344_822,
        922_337_203_685_477_581,   878_416_384_462_359_601,
        838_488_366_986_797_801,   802_032_351_030_850_070,
        768_614_336_404_564_651,   737_869_762_948_382_065,
        709_490_156_681_136_601,   683_212_743_470_724_134,
        658_812_288_346_769_701,   636_094_623_231_363_849,
        614_891_469_123_651_721,   595_056_260_442_243_601];

   --  1 / (2 K + 1), fine: atanh z / z as a series in z**2, past the
   --  fine grid at |z| < 0.0304.
   Inverse_Odds : constant Fine_Coefficients (0 .. 5) :=
     [1_152_921_504_606_846_976, 384_307_168_202_282_325,
      230_584_300_921_369_395,   164_703_072_086_692_425,
      128_102_389_400_760_775,   104_811_045_873_349_725];
   --!format on

   --  The position of X's highest set bit.
   subtype Bit_Position is Natural range 0 .. Val_Bits;

   function Top_Bit (X : Log_Arg) return Bit_Position
   with Post => Wide (X) >= Powers_Of_Two (Top_Bit'Result)
   is
   begin
      for B in reverse 1 .. Val_Bits loop
         if Wide (X) >= Powers_Of_Two (B) then
            return B;
         end if;
      end loop;
      return 0;
   end Top_Bit;

   --  2 atanh ((U - 1) / (U + 1)) for a fine U within a sixteenth of one.
   function Twice_Atanh (U : Fine) return Fine
   with Pre => U in Fine_One .. 2 * Fine_One
   is
      Z : constant Fine :=
        Clamp (Div_Round ((U - Fine_One) * Fine_One, U + Fine_One), Fine_One);
   begin
      return
        Clamp
          (2 * Fine_Mul (Z, Fine_Horner (Inverse_Odds, Fine_Mul (Z, Z))),
           Fine_Bound);
   end Twice_Atanh;

   function Log (X : Log_Arg) return Val is
      K   : constant Bit_Position := Top_Bit (X);
      M   : constant Wide := Wide (X) * Powers_Of_Two (Fine_Frac - K);
      J   : constant Natural :=
        Natural (Clamp ((M - Fine_One) / 2**(Fine_Frac - 4), 15));
      U   : constant Wide :=
        Clamp
          (Fine_Mul (Clamp (M, Fine_Bound), Inverse_Sixteenths (J)),
           2 * Fine_One);
      Sum : constant Wide :=
        Wide (K - Frac)
        * Fine_Ln2
        + Log_Sixteenths (J)
        + Twice_Atanh (Wide'Max (U, Fine_One));
   begin
      return Val (To_Grid (Sum));
   end Log;

   ---------------------------------------------------------------------
   --  Rational approximations on the grid.
   ---------------------------------------------------------------------

   type Coefficients is array (Natural range <>) of Val;

   --  C (0) + X (C (1) + X (C (2) + ...)), each stage held to the values.
   --  The most terms an approximation here has.
   Max_Terms : constant := 16;

   function Horner (C : Coefficients; X : Val) return Val
   with Pre => C'Length <= Max_Terms
   is
      Acc : Val := 0;
   begin
      for K in reverse C'Range loop
         Acc := Val (Clamp (Wide (C (K)) + Product_Of (X, Acc), Val_Bound));
      end loop;
      return Acc;
   end Horner;

   --  N / D for a denominator the approximation keeps at least one; the
   --  floor at one states that, and never binds.
   function Ratio (N, D : Val) return Val
   is (Val (Clamp (Quotient_Of (N, Val'Max (D, One)), Val_Bound)));

   --!format off
   --  Abramowitz and Stegun 26.2.17: p, and b1 .. b5.
   Cdf_Rate : constant := 254_692_962_530;
   Cdf_B    : constant Coefficients (0 .. 4) :=
     [351_163_705_932, -392_046_024_353, 1_958_755_706_358,
      -2_002_492_124_968, 1_462_652_202_819];
   --!format on

   Inv_Sqrt_2_Pi : constant := 438_641_676_113;

   --  Past this the upper tail is under half a unit.
   Cdf_Reach : constant := 31 * One / 4;

   --  The upper tail beyond A >= 0.
   function Upper_Tail (A : Nonnegative) return Probability
   with Pre => A <= Cdf_Reach
   is
      K    : constant Val :=
        Val
          (Clamp
             (Quotient_Of (One, One + Val (Product_Of (Cdf_Rate, A))), One));
      Poly : constant Val :=
        Val (Clamp (Product_Of (K, Horner (Cdf_B, K)), 2 * One));
      Arg  : constant Val :=
        Val (Wide'Min (Product_Of (A, A) / 2, -Exp_Floor));
      Pdf  : constant Val :=
        Val (Clamp (Product_Of (Inv_Sqrt_2_Pi, Exp (-Arg)), One));
   begin
      return Val (Wide'Max (0, Clamp (Product_Of (Pdf, Poly), One)));
   end Upper_Tail;

   function Norm_Cdf (X : Val) return Probability is
      A     : constant Nonnegative := (if X < 0 then -X else X);
      Upper : constant Probability :=
        (if A > Cdf_Reach then 0 else Upper_Tail (A));
   begin
      return (if X >= 0 then One - Upper else Upper);
   end Norm_Cdf;

   --!format off
   --  Wichura's AS 241: the central fraction A / B, and the tails' C / D
   --  (for r <= 5) and E / F (beyond).
   Central_A : constant Coefficients (0 .. 7) :=
     [3_724_191_978_462, 146_390_811_988_507, 2_167_787_175_079_987,
      15_098_156_964_236_858, 50_491_722_317_932_882,
      73_959_497_285_562_873, 36_757_306_577_399_584,
      2_758_763_656_169_775];
   Central_B : constant Coefficients (0 .. 7) :=
     [1_099_511_627_776, 46_523_999_116_341, 755_570_105_194_111,
      5_930_981_248_059_551, 23_324_813_503_842_711,
      43_219_488_495_609_330, 31_587_963_821_799_896,
      5_746_592_331_615_081];
   --  The tails' coefficients at 2**-52: their highest terms are too
   --  small for the grid to hold to the accuracy the fraction needs.
   Near_C : constant Fine_Coefficients (0 .. 7) :=
     [6_410_590_841_557_610, 20_853_187_798_550_122,
      25_983_505_536_685_482, 16_428_448_356_107_656,
      5_721_635_312_334_258, 1_088_883_583_814_535, 102_339_099_826_098,
      3_488_240_637_686];
   Near_D : constant Fine_Coefficients (0 .. 7) :=
     [4_503_599_627_370_496, 9_246_753_044_646_033, 7_549_766_096_545_331,
      3_106_435_912_811_236, 667_001_013_050_888, 68_448_709_072_431,
      2_466_143_271_909, 4_732_158];
   Far_E : constant Fine_Coefficients (0 .. 7) :=
     [29_984_536_871_539_866, 24_606_699_689_951_244,
      8_038_144_140_092_485, 1_335_590_080_779_636, 119_490_358_865_212,
      5_596_447_379_605, 122_117_606_490, 905_374_125];
   Far_F : constant Fine_Coefficients (0 .. 7) :=
     [4_503_599_627_370_496, 2_701_404_101_929_919, 616_677_360_699_519,
      66_992_671_566_476, 3_543_743_525_817, 83_150_784_867, 640_191_983,
      9];
   --!format on

   Half          : constant := One / 2;
   Central_Reach : constant := 467_292_441_805;
   Central_Shift : constant := 198_599_287_767;
   Near_Shift    : constant := 1_759_218_604_442;
   Far_Reach     : constant := 5 * One;

   --  The central fraction, for Q = P - 1/2 within 0.425.
   function Central (Q : Val) return Val
   with Pre => Q in -Central_Reach .. Central_Reach
   is
      R : constant Val := Central_Shift - Val (Product_Of (Q, Q));
   begin
      return
        Val
          (Clamp
             (Product_Of
                (Q, Ratio (Horner (Central_A, R), Horner (Central_B, R))),
              Val_Bound));
   end Central;

   --  The tails' scale, 2**-52, and how far a grid value is raised to
   --  reach it.
   Tail_Frac : constant := 52;
   Tail_One  : constant := 2**Tail_Frac;
   Tail_Lift : constant := 2**(Tail_Frac - Frac);

   --  The tail fraction N (X) / D (X) for a grid X within eight, on the
   --  grid.
   function Tail_Ratio (N, D : Fine_Coefficients; X : Val) return Val
   with Pre => X in -8 * One .. 8 * One
   is
      Lifted : constant Fine := Wide (X) * Tail_Lift;
      Num    : constant Fine := Fine_Horner (N, Lifted, Tail_Frac);
      Den    : constant Fine := Fine_Horner (D, Lifted, Tail_Frac);
   begin
      return
        Val
          (Clamp (Div_Round (Num * One, Wide'Max (Den, Tail_One)), Val_Bound));
   end Tail_Ratio;

   --  A tail, for the smaller of P and 1 - P: R = sqrt (-log M), and a
   --  fraction in R less a shift.  Its sign is the caller's.
   function Tail (M : Open_Probability) return Val is
      R : constant Nonnegative :=
        Sqrt (Val (Wide'Max (0, Clamp (-Wide (Log (M)), Val_Bound))));
   begin
      if R <= Far_Reach then
         return Tail_Ratio (Near_C, Near_D, R - Near_Shift);
      end if;
      return Tail_Ratio (Far_E, Far_F, Val'Min (R - Far_Reach, 8 * One));
   end Tail;

   function Inv_Norm_Cdf (P : Open_Probability) return Val is
      Q : constant Val := P - Half;
   begin
      if Q in -Central_Reach .. Central_Reach then
         return Central (Q);
      elsif Q < 0 then
         return -Tail (P);
      else
         return Tail (One - P);
      end if;
   end Inv_Norm_Cdf;

end Abacus.Elementary;
