with AUnit.Assertions; use AUnit.Assertions;

with Abacus;       use Abacus;
with Abacus.Arith; use Abacus.Arith;
with Abacus.Stats; use Abacus.Stats;

package body Abacus_Stats_Tests is

   function Whole (V : Vector) return Vector is
      Result : Vector (V'Range);
   begin
      for I in V'Range loop
         Result (I) := V (I) * One;
      end loop;
      return Result;
   end Whole;

   --  The correlation of X and Y on the grid: 0.8455943246644705.
   Pearson : constant := 929_740_792_350;

   X : constant Vector := Whole ([2, 4, 4, 4, 5, 5, 7, 9]);
   Y : constant Vector := Whole ([1, 3, 2, 5, 4, 6, 8, 7]);

   procedure Near (Got, Want : Raw; Slack : Raw; What : String) is
   begin
      Assert
        (abs (Got - Want) <= Slack,
         What & ":" & Got'Image & " want" & Want'Image);
   end Near;

   --  Means and variances of a table checked by hand.
   procedure Test_Moments (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Assert (Mean (X) = 5 * One, "the mean");
      Assert (Variance (X, Population) = 4 * One, "population variance");
      Assert (Variance (X, Sample) = Div (32 * One, 7 * One), "sample");
      Assert (Std_Dev (X, Population) = 2 * One, "the deviation");
      Assert
        (Weighted_Mean (X, Whole ([1, 1, 1, 1, 2, 2, 0, 0])) = 17 * One / 4,
         "a weighted mean");
      Assert (Mean ([1, 2]) = 2, "a mean rounds half away");
      Assert (Mean ([-1, -2]) = -2, "and below zero");
   end Test_Moments;

   --  Covariance and correlation of two series.
   procedure Test_Pairs (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      R : constant Checked := Correlation (X, Y);
   begin
      Assert (Covariance (X, Y, Population) = 31 * One / 8, "covariance");
      Assert (Covariance (X, Y, Sample) = Div (31 * One, 7 * One), "sample");
      Assert (R.Status = Ok, "a correlation");
      Near (R.Value, Pearson, 2, "the correlation");
      Assert (Correlation (X, X).Value = One, "itself");
      Assert
        (Correlation (X, Whole ([3, 3, 3, 3, 3, 3, 3, 3])).Status = Undefined,
         "with a constant");
   end Test_Pairs;

   --  Skewness and kurtosis on standardized values.
   procedure Test_Shape (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Assert (Skewness (X, Population) = (21 * One / 32, Ok), "skewness");
      Assert (Kurtosis (X, Population) = (89 * One / 32, Ok), "kurtosis");
      Assert
        (Skewness (Whole ([1, 1]), Population).Status = Undefined,
         "no spread");
   end Test_Shape;

   --  Order does not matter: the sums are exact.
   procedure Test_Order_Free (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Back : constant Vector := Whole ([9, 7, 5, 5, 4, 4, 4, 2]);
   begin
      Assert (Variance (X, Sample) = Variance (Back, Sample), "reversed");
      Assert (Mean (X) = Mean (Back), "the mean, reversed");
   end Test_Order_Free;

   --  Rows to z-scores, and their correlation matrix.
   procedure Test_Standardize (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      R       : Matrix (1 .. 2, 1 .. 8);
      M       : Moments (2);
      C       : Matrix (1 .. 2, 1 .. 2);
      Outcome : Estimate_Outcome;
   begin
      for J in 1 .. 8 loop
         R (1, J) := X (J);
         R (2, J) := Y (J);
      end loop;
      Standardize (R, M, Outcome);
      Assert (Outcome = (Estimated, 0), "standardized");
      Assert (M.Mean (1) = 5 * One and then M.Mean (2) = 9 * One / 2, "means");
      Correlate (R, C, Outcome);
      Assert (Outcome = (Estimated, 0), "correlated");
      Near (C (1, 1), One, 2, "a unit diagonal");
      Near (C (1, 2), Pearson, 4, "the correlation");
      Assert (C (1, 2) = C (2, 1), "symmetric");
      for J in 1 .. 8 loop
         R (2, J) := One;
      end loop;
      Standardize (R, M, Outcome);
      Assert (Outcome = (Degenerate, 2), "a row with no spread is named");
   end Test_Standardize;

   overriding
   procedure Register_Tests (T : in out Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine (T, Test_Moments'Access, "Means and variances");
      Register_Routine (T, Test_Pairs'Access, "Covariance and correlation");
      Register_Routine (T, Test_Shape'Access, "Skewness and kurtosis");
      Register_Routine (T, Test_Order_Free'Access, "Order does not matter");
      Register_Routine (T, Test_Standardize'Access, "z-scores and Z Z'");
   end Register_Tests;

   overriding
   function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("Abacus.Stats");
   end Name;

end Abacus_Stats_Tests;
