with AUnit.Assertions; use AUnit.Assertions;
with Fixtures;
with Spike;            use Spike;
with Spike.Estimate;

package body Spike_Estimate_Tests is

   generic
      Frac : Frac_Bits;
   procedure Check_Bucket;

   --  Two assets over three days whose moments are exact on the grid:
   --  means 2, deviations 1, correlation -1.
   procedure Test_Exact (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      package E is new Spike.Estimate (40);
      use type E.Estimate_Outcome;
      One     : constant := 2**40;
      R       : Matrix (1 .. 2, 1 .. 3) :=
        [[One, 2 * One, 3 * One], [3 * One, 2 * One, One]];
      M       : E.Moments (2);
      C       : Matrix (1 .. 2, 1 .. 2);
      Outcome : E.Estimate_Outcome;
   begin
      E.Standardize (R, M, Outcome);
      Assert (Outcome = (E.Estimated, 0), "standardized");
      Assert (M.Mean = [2 * One, 2 * One], "means");
      Assert (M.Sigma = [One, One], "deviations");
      Assert (M.Inv_Sigma = [One, One], "inverse deviations");
      Assert (R = [[-One, 0, One], [One, 0, -One]], "z-scores");
      E.Correlate (R, C, Outcome);
      Assert (Outcome = (E.Estimated, 0), "correlated");
      Assert (C = [[One, -One], [-One, One]], "correlation");
   end Test_Exact;

   --  An asset that never moves has no deviation, and is named.
   procedure Test_Degenerate (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      package E is new Spike.Estimate (40);
      use type E.Estimate_Outcome;
      R       : Matrix (1 .. 2, 1 .. 3) :=
        [[2**40, 2**41, 3 * 2**40], [5, 5, 5]];
      M       : E.Moments (2);
      Outcome : E.Estimate_Outcome;
   begin
      E.Standardize (R, M, Outcome);
      Assert (Outcome = (E.Degenerate, 2), "asset 2 is degenerate");
   end Test_Degenerate;

   --  The bucket's means and deviations within one unit of the grid of
   --  the oracle's, and the first and last correlation rows within four.
   procedure Check_Bucket is
      package E is new Spike.Estimate (Frac);
      use type E.Estimate_Outcome;
      R       : Matrix := Fixtures.Returns (Frac);
      Oracle  : constant Matrix := Fixtures.Moments (Frac);
      M       : E.Moments (Fixtures.Assets);
      C       : Matrix (1 .. Fixtures.Assets, 1 .. Fixtures.Assets);
      Outcome : E.Estimate_Outcome;
      Last    : constant := Fixtures.Assets;
   begin
      E.Standardize (R, M, Outcome);
      Assert (Outcome = (E.Estimated, 0), "standardized at" & Frac'Image);
      E.Correlate (R, C, Outcome);
      Assert (Outcome = (E.Estimated, 0), "correlated at" & Frac'Image);
      for I in 1 .. Last loop
         Assert
           (abs (M.Mean (I) - Oracle (1, I)) <= 1,
            "mean" & I'Image & " at" & Frac'Image);
         Assert
           (abs (M.Sigma (I) - Oracle (2, I)) <= 1,
            "deviation" & I'Image & " at" & Frac'Image);
         Assert
           (abs (C (1, I) - Oracle (3, I)) <= 4,
            "correlation (1," & I'Image & ") at" & Frac'Image);
         Assert
           (abs (C (Last, I) - Oracle (4, I)) <= 4,
            "correlation (last," & I'Image & ") at" & Frac'Image);
      end loop;
   end Check_Bucket;

   procedure Check_32 is new Check_Bucket (32);
   procedure Check_40 is new Check_Bucket (40);
   procedure Check_48 is new Check_Bucket (48);

   procedure Test_Bucket (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Check_32;
      Check_40;
      Check_48;
   end Test_Bucket;

   overriding
   procedure Register_Tests (T : in out Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine (T, Test_Exact'Access, "Exact moments");
      Register_Routine (T, Test_Degenerate'Access, "A still asset is named");
      Register_Routine
        (T, Test_Bucket'Access, "The bucket against the oracle");
   end Register_Tests;

   overriding
   function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("Spike.Estimate");
   end Name;

end Spike_Estimate_Tests;
