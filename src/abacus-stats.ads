with Abacus.Arith;

--  Means, variances, covariances and correlations from sums held exactly
--  at 128 bits, skewness and kurtosis on standardized values, and the
--  table forms: series held one row each, standardized in place to
--  z-scores, and their correlation matrix Z Z' / (n - 1).  Every sum is
--  exact, so the order of the data cannot change a result.

package Abacus.Stats
  with SPARK_Mode
is

   use type Arith.Status;

   --  A datum's magnitude is at most 256: a variance of such data, and
   --  a covariance, is then a value, and a window of Max_N rows keeps
   --  its sums of products inside 128 bits.
   Datum_Bound : constant := 2**48;
   subtype Datum is Val range -Datum_Bound .. Datum_Bound;

   function Is_Data (X : Vector) return Boolean
   is (for all I in X'Range => X (I) in Datum);

   --  Whether a spread divides by n - 1 or by n.
   type Divisor_Kind is (Sample, Population);

   --  The fewest data a spread of the kind needs.
   function Least (Kind : Divisor_Kind) return Positive
   is (if Kind = Sample then 2 else 1);

   function Mean (X : Vector) return Datum
   with Pre => X'Length > 0 and then Is_Data (X);

   --  The mean of X weighted by W: the weights are not negative and not
   --  all zero.
   function Weighted_Mean (X, W : Vector) return Datum
   with
     Pre =>
       X'Length > 0
       and then W'First = X'First
       and then W'Last = X'Last
       and then Is_Data (X)
       and then Is_Data (W)
       and then (for all I in W'Range => W (I) >= 0)
       and then (for some I in W'Range => W (I) > 0);

   subtype Nonnegative is Val range 0 .. Val'Last;

   function Variance (X : Vector; Kind : Divisor_Kind) return Nonnegative
   with Pre => X'Length >= Least (Kind) and then Is_Data (X);

   --  The square root of the variance, rounded to nearest.
   function Std_Dev (X : Vector; Kind : Divisor_Kind) return Nonnegative
   with Pre => X'Length >= Least (Kind) and then Is_Data (X);

   function Covariance (X, Y : Vector; Kind : Divisor_Kind) return Val
   with
     Pre =>
       X'Length >= Least (Kind)
       and then Y'First = X'First
       and then Y'Last = X'Last
       and then Is_Data (X)
       and then Is_Data (Y);

   --  Pearson's correlation, by z-scores; Undefined when either series
   --  has no spread.
   function Correlation (X, Y : Vector) return Arith.Checked
   with
     Pre  =>
       X'Length >= 2
       and then Y'First = X'First
       and then Y'Last = X'Last
       and then Is_Data (X)
       and then Is_Data (Y),
     Post =>
       Correlation'Result.Value in -One .. One
       and then Correlation'Result.Status /= Arith.Saturated;

   --  The mean of z**3 and of z**4, z the standardized data (deviation
   --  by Kind); Undefined when the data have no spread.
   function Skewness (X : Vector; Kind : Divisor_Kind) return Arith.Checked
   with Pre => X'Length >= Least (Kind) and then Is_Data (X);

   function Kurtosis (X : Vector; Kind : Divisor_Kind) return Arith.Checked
   with Pre => X'Length >= Least (Kind) and then Is_Data (X);

   ---------------------------------------------------------------------
   --  Tables: one series per row.
   ---------------------------------------------------------------------

   --  Per series: the mean, the deviation (divisor n - 1), and the
   --  inverse deviation every z-score was scaled by.
   type Moments (N : Index) is record
      Mean      : Vector (1 .. N);
      Sigma     : Vector (1 .. N);
      Inv_Sigma : Vector (1 .. N);
   end record;

   type Estimate_Result is (Estimated, Degenerate, Out_Of_Range);

   --  How an estimate ended, and the series it ended at (zero when it
   --  succeeded).
   type Estimate_Outcome is record
      Result : Estimate_Result;
      Series : Count;
   end record;

   --  Each row of R, one series by observation, becomes its z-scores.  A
   --  series with no spread is Degenerate.  The deviation is taken from
   --  the variance raised by fours while it fits, so a small one keeps
   --  its digits, and the inverse from that lifted root.
   procedure Standardize
     (R : in out Matrix; M : out Moments; Outcome : out Estimate_Outcome)
   with
     Pre =>
       R'First (1) = 1
       and then R'Last (1) = M.N
       and then R'First (2) = 1
       and then R'Last (2) >= 2;

   --  C = Z Z' / (observations - 1), one rounding per entry.
   procedure Correlate
     (Z : Matrix; C : out Matrix; Outcome : out Estimate_Outcome)
   with
     Pre =>
       Z'First (1) = 1
       and then Z'First (2) = 1
       and then Z'Last (2) >= 2
       and then C'First (1) = 1
       and then C'Last (1) = Z'Last (1)
       and then C'First (2) = 1
       and then C'Last (2) = Z'Last (1);

end Abacus.Stats;
