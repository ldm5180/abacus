--  Moments and correlations of returns held one row per asset: each row
--  standardized in place to z-scores, then their correlation matrix, so
--  every matrix downstream has entries in -1 .. 1.

generic
   Frac : Frac_Bits;
package Spike.Estimate with SPARK_Mode is

   --  Per asset: the mean, the standard deviation (divisor n - 1), and
   --  the reciprocal deviation every z-score was scaled by.
   type Moments (N : Index) is record
      Mean      : Vector (1 .. N);
      Sigma     : Vector (1 .. N);
      Inv_Sigma : Vector (1 .. N);
   end record;

   type Estimate_Result is (Estimated, Degenerate, Out_Of_Range);

   --  How an estimate ended, and the asset it ended at (zero when it
   --  succeeded).
   type Estimate_Outcome is record
      Result : Estimate_Result;
      Asset  : Count;
   end record;

   --  Each row of R, one asset's returns by day, becomes its z-scores.
   --  An asset with no deviation is Degenerate.
   procedure Standardize
     (R : in out Matrix; M : out Moments; Outcome : out Estimate_Outcome)
   with
     Pre =>
       R'First (1) = 1
       and then R'Last (1) = M.N
       and then R'First (2) = 1
       and then R'Last (2) >= 2;

   --  C = Z Z' / (days - 1), one rounding per entry.
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

end Spike.Estimate;
