with Abacus.Elementary;
with Abacus.Vectors;

package body Abacus.Stats
  with SPARK_Mode
is

   use Abacus.Arith;

   --  The largest deviation from a mean of data, and the bound on a sum
   --  of Max_N squared deviations: 2**49 squared, 2**12 times.
   Deviation_Bound : constant := 2 * Datum_Bound;
   subtype Deviation is Val range -Deviation_Bound .. Deviation_Bound;

   Square_Bound  : constant := Deviation_Bound * Deviation_Bound;
   Squares_Bound : constant := Max_N * Square_Bound;
   subtype Squares is Wide range -Squares_Bound .. Squares_Bound;

   function Mean (X : Vector) return Datum
   is (Val
         (Wide'Max
            (-Datum_Bound,
             Wide'Min
               (Div_Round (Vectors.Sum (X), Wide (X'Length)), Datum_Bound))));

   function Weighted_Mean (X, W : Vector) return Datum is
      Total : constant Wide := Vectors.Sum (W);
   begin
      return
        Val
          (Wide'Max
             (-Datum_Bound,
              Wide'Min
                (Div_Round (Vectors.Dot_Exact (X, W), Wide'Max (Total, 1)),
                 Datum_Bound)));
   end Weighted_Mean;

   --  The sum of (X (I) - Mx) (Y (I) - My), exact at scale One * One.
   function Centered_Dot (X, Y : Vector; Mx, My : Datum) return Squares
   with
     Pre =>
       Y'First = X'First
       and then Y'Last = X'Last
       and then Is_Data (X)
       and then Is_Data (Y)
   is
      Acc : Wide := 0;
   begin
      for K in 0 .. X'Length - 1 loop
         Acc :=
           Acc
           + Wide (Deviation (X (X'First + K) - Mx))
             * Wide (Deviation (Y (Y'First + K) - My));
         pragma
           Loop_Invariant
             (Acc
              in -(Wide (K + 1) * Square_Bound)
               .. Wide (K + 1) * Square_Bound);
      end loop;
      return Acc;
   end Centered_Dot;

   --  What a sum of squared or crossed deviations is divided by.
   function Divisor_Of (Len : Positive; Kind : Divisor_Kind) return Divisor
   is (Wide (if Kind = Sample then Len - 1 else Len) * One)
   with Pre => Len >= Least (Kind) and then Len <= Max_N;

   --  A spread at scale One * One brought to the grid, held to the values.
   function Spread
     (S : Squares; Len : Positive; Kind : Divisor_Kind) return Val
   is (Val
         (Wide'Max
            (Wide (Val'First),
             Wide'Min
               (Div_Round (S, Divisor_Of (Len, Kind)), Wide (Val'Last)))))
   with Pre => Len >= Least (Kind) and then Len <= Max_N;

   function Variance (X : Vector; Kind : Divisor_Kind) return Nonnegative is
      M : constant Datum := Mean (X);
   begin
      return Val'Max (0, Spread (Centered_Dot (X, X, M, M), X'Length, Kind));
   end Variance;

   function Std_Dev (X : Vector; Kind : Divisor_Kind) return Nonnegative
   is (Elementary.Sqrt (Variance (X, Kind)));

   function Covariance (X, Y : Vector; Kind : Divisor_Kind) return Val
   is (Spread (Centered_Dot (X, Y, Mean (X), Mean (Y)), X'Length, Kind));

   ---------------------------------------------------------------------
   --  Deviations, lifted for their digits.
   ---------------------------------------------------------------------

   subtype Root_Arg is Elementary.Root_Arg;

   --  A variance at scale One * One, raised by fours while it stays a
   --  root argument, beside One * One and one each raised by twos: the
   --  root of V over Unit is the deviation, Top over that root the
   --  inverse, both with the digits a small deviation would lose.
   type Lifted is record
      V    : Root_Arg;
      Top  : Wide;
      Unit : Wide;
   end record;

   Max_Lift : constant := 20;
   Top_Max  : constant := 2**124;
   Root_Top : constant := 2**Elementary.Root_Bits;

   function Lift (V : Root_Arg) return Lifted
   with
     Post =>
       Lift'Result.Top in 1 .. Top_Max
       and then Lift'Result.Unit in 1 .. 2**Max_Lift
   is
      L : Lifted := (V, Wide (One) * One, 1);
   begin
      for Step in 1 .. Max_Lift loop
         exit when
           L.V >= Root_Top / 4
           or else L.Top > Top_Max / 2
           or else L.Unit > 2**(Max_Lift - 1);
         L := (L.V * 4, L.Top * 2, L.Unit * 2);
         pragma
           Loop_Invariant
             (L.Top in 1 .. Top_Max and then L.Unit in 1 .. 2**Max_Lift);
      end loop;
      return L;
   end Lift;

   --  A deviation and its inverse, both at scale One; a zero deviation
   --  means the series did not move.
   type Spread_Pair is record
      Sigma : Wide;
      Inv   : Wide;
   end record;

   function Spread_Of (V : Root_Arg) return Spread_Pair is
      L : constant Lifted := Lift (V);
      R : constant Val := Elementary.Root (L.V);
   begin
      if R < 1 then
         return (0, 0);
      end if;
      return (Div_Round (Wide (R), L.Unit), Div_Round (L.Top, Wide (R)));
   end Spread_Of;

   --  The inverse deviation of data whose squared deviations sum to S,
   --  as a value; zero when there is no spread or it does not fit.
   function Inverse_Spread
     (S : Squares; Len : Positive; Kind : Divisor_Kind) return Val
   with Pre => Len >= Least (Kind) and then Len <= Max_N
   is
      V : constant Wide := Div_Round (S, Divisor_Of (Len, Kind) / One);
      P : Spread_Pair;
   begin
      if V not in Root_Arg then
         return 0;
      end if;
      P := Spread_Of (V);
      return (if P.Sigma >= 1 and then Fits (P.Inv) then Val (P.Inv) else 0);
   end Inverse_Spread;

   --  Data's z-scores into Z, with the inverse deviation by Kind; Ok is
   --  False when there is no spread or a score does not fit.
   procedure Scores
     (X : Vector; Kind : Divisor_Kind; Z : out Vector; Ok : out Boolean)
   with
     Pre =>
       X'Length >= Least (Kind)
       and then Is_Data (X)
       and then Z'First = X'First
       and then Z'Last = X'Last
   is
      M   : constant Datum := Mean (X);
      Inv : constant Val :=
        Inverse_Spread (Centered_Dot (X, X, M, M), X'Length, Kind);
   begin
      Z := [others => 0];
      Ok := Inv >= 1;
      for I in X'Range loop
         Store (Product_Of (Deviation (X (I) - M), Inv), Z (I), Ok);
      end loop;
   end Scores;

   function Correlation (X, Y : Vector) return Checked is
      Zx, Zy     : Vector (X'Range);
      Ok_X, Ok_Y : Boolean;
      R          : Wide;
   begin
      Scores (X, Sample, Zx, Ok_X);
      Scores (Y, Sample, Zy, Ok_Y);
      if not (Ok_X and then Ok_Y) then
         return (Value => 0, Status => Undefined);
      end if;
      R := Div_Round (Vectors.Dot_Exact (Zx, Zy), Wide (X'Length - 1) * One);
      return (Value => Val (Wide'Max (-One, Wide'Min (R, One))), Status => Ok);
   end Correlation;

   --  The mean of z**Power over standardized data, Power 3 or 4.
   type Power is range 3 .. 4;

   --  A z-score's magnitude is at most sqrt (n) <= 64; held there.  Its
   --  square then fits a value.
   Z_Bound : constant := 64 * One;
   subtype Z_Score is Val range -Z_Bound .. Z_Bound;

   function Square (Z : Z_Score) return Nonnegative
   is (Val (Wide'Max (0, Wide'Min (Product_Of (Z, Z), Wide (Val'Last)))));

   --  The bound on one term of a moment: two values' product.
   Power_Bound : constant := Vectors.Term_Bound;

   function Z_Power (Z : Z_Score; P : Power) return Wide
   is (if P = 3
       then Wide (Z) * Wide (Square (Z))
       else Wide (Square (Z)) * Wide (Square (Z)))
   with Post => Z_Power'Result in -Power_Bound .. Power_Bound;

   function Moment (X : Vector; Kind : Divisor_Kind; P : Power) return Checked
   with Pre => X'Length >= Least (Kind) and then Is_Data (X)
   is
      Z   : Vector (X'Range);
      Ok  : Boolean;
      Acc : Wide := 0;
   begin
      Scores (X, Kind, Z, Ok);
      if not Ok then
         return (Value => 0, Status => Undefined);
      end if;
      for I in Z'Range loop
         Acc :=
           Acc + Z_Power (Val'Max (-Z_Bound, Val'Min (Z (I), Z_Bound)), P);
         pragma
           Loop_Invariant
             (Acc
              in -(Wide (I - Z'First + 1) * Power_Bound)
               .. Wide (I - Z'First + 1) * Power_Bound);
      end loop;
      return Saturate (Div_Round (Acc, Wide (X'Length) * One));
   end Moment;

   function Skewness (X : Vector; Kind : Divisor_Kind) return Checked
   is (Moment (X, Kind, 3));

   function Kurtosis (X : Vector; Kind : Divisor_Kind) return Checked
   is (Moment (X, Kind, 4));

   ---------------------------------------------------------------------
   --  Tables.
   ---------------------------------------------------------------------

   Row_Bound : constant := Max_N * Val_Bound;

   --  The sum of row I.
   function Row_Sum (R : Matrix; I : Index) return Wide
   with
     Pre  => I in R'Range (1),
     Post => Row_Sum'Result in -Row_Bound .. Row_Bound
   is
      S : Wide := 0;
   begin
      for T in R'Range (2) loop
         S := S + Wide (R (I, T));
         pragma
           Loop_Invariant
             (S
              in -(Wide (T - R'First (2) + 1) * Val_Bound)
               .. Wide (T - R'First (2) + 1) * Val_Bound);
      end loop;
      return S;
   end Row_Sum;

   --  Row I less V, each entry checked into range.
   procedure Center (R : in out Matrix; I : Index; V : Val; Ok : out Boolean)
   with Pre => I in R'Range (1)
   is
   begin
      Ok := True;
      for T in R'Range (2) loop
         Ok := Fits (Wide (R (I, T)) - Wide (V));
         exit when not Ok;
         R (I, T) := R (I, T) - V;
      end loop;
   end Center;

   --  Row I times S, rounded, each entry checked into range.
   procedure Scale (R : in out Matrix; I : Index; S : Val; Ok : out Boolean)
   with Pre => I in R'Range (1)
   is
      P : Wide;
   begin
      Ok := True;
      for T in R'Range (2) loop
         P := Product_Of (R (I, T), S);
         Ok := Fits (P);
         exit when not Ok;
         R (I, T) := Val (P);
      end loop;
   end Scale;

   --  The sum over columns of M (I, K) * M (J, K), exact.
   function Row_Dot (M : Matrix; I, J : Index) return Vectors.Dot_Sum
   with Pre => I in M'Range (1) and then J in M'Range (1)
   is
      Acc : Wide := 0;
   begin
      for K in M'Range (2) loop
         Acc := Acc + Wide (M (I, K)) * Wide (M (J, K));
         pragma
           Loop_Invariant
             (Acc
              in -(Wide (K - M'First (2) + 1) * Vectors.Term_Bound)
               .. Wide (K - M'First (2) + 1) * Vectors.Term_Bound);
      end loop;
      return Acc;
   end Row_Dot;

   --  Row I's moments into M, and its z-scores in place.
   procedure Standardize_Row
     (R      : in out Matrix;
      I      : Index;
      M      : in out Moments;
      Result : out Estimate_Result)
   with
     Pre =>
       R'First (1) = 1
       and then R'Last (1) = M.N
       and then I <= M.N
       and then R'First (2) = 1
       and then R'Last (2) >= 2
   is
      Days : constant Wide := Wide (R'Length (2));
      Mean : constant Wide := Div_Round (Row_Sum (R, I), Days);
      Ok   : Boolean;
      V    : Wide;
      S    : Spread_Pair;
   begin
      Result := Out_Of_Range;
      if not Fits (Mean) then
         return;
      end if;
      Center (R, I, Val (Mean), Ok);
      V := (if Ok then Div_Round (Row_Dot (R, I, I), Days - 1) else -1);
      if V not in Root_Arg then
         return;
      end if;
      S := Spread_Of (V);
      if S.Sigma < 1 then
         Result := Degenerate;
      elsif Fits (S.Sigma) and then Fits (S.Inv) then
         M.Mean (I) := Val (Mean);
         M.Sigma (I) := Val (S.Sigma);
         M.Inv_Sigma (I) := Val (S.Inv);
         Scale (R, I, Val (S.Inv), Ok);
         Result := (if Ok then Estimated else Out_Of_Range);
      end if;
   end Standardize_Row;

   procedure Standardize
     (R : in out Matrix; M : out Moments; Outcome : out Estimate_Outcome)
   is
      Result : Estimate_Result;
   begin
      M :=
        (N         => M.N,
         Mean      => [others => 0],
         Sigma     => [others => 0],
         Inv_Sigma => [others => 0]);
      Outcome := (Estimated, 0);
      for I in R'Range (1) loop
         Standardize_Row (R, I, M, Result);
         if Result /= Estimated then
            Outcome := (Result, I);
            return;
         end if;
      end loop;
   end Standardize;

   procedure Correlate
     (Z : Matrix; C : out Matrix; Outcome : out Estimate_Outcome)
   is
      Scale : constant Wide := Wide (Z'Length (2) - 1) * One;
      Q     : Wide;
   begin
      C := [others => [others => 0]];
      Outcome := (Estimated, 0);
      for I in Z'Range (1) loop
         for J in Z'First (1) .. I loop
            Q := Div_Round (Row_Dot (Z, I, J), Scale);
            if not Fits (Q) then
               Outcome := (Out_Of_Range, I);
               return;
            end if;
            C (I, J) := Val (Q);
            C (J, I) := Val (Q);
         end loop;
      end loop;
   end Correlate;

end Abacus.Stats;
