with AUnit.Assertions; use AUnit.Assertions;
with Fixtures;
with Spike;            use Spike;
with Spike.Bucket;

package body Spike_Bucket_Tests is

   --  The bucket solved end to end at one grid: every weight within 1e-6
   --  of the oracle's, and the solver's own residuals either certify it
   --  (Converged) or, where the grid is too coarse for them to, run it
   --  to the cap (Exhausted).
   generic
      Frac : Frac_Bits;
      Certified : Boolean;
   procedure Check_Bucket;

   procedure Check_Bucket is
      package B is new Spike.Bucket (Frac);
      use type B.Stage;
      use type B.A.Result_Kind;
      One     : constant Raw := 2**Frac;
      R       : Matrix := Fixtures.Returns (Frac);
      Oracle  : constant Vector := Fixtures.Weights (Frac);
      W       : Vector (1 .. Fixtures.Assets);
      Outcome : B.Bucket_Outcome;
      Within  : constant Raw := One / 1_000_000;
   begin
      B.Solve_Bucket (R, B.Default_Terms, B.Default_Settings, W, Outcome);
      Assert
        (Outcome.Stage = B.Done,
         "stage " & Outcome.Stage'Image & " at" & Frac'Image);
      Assert
        (Outcome.Result = (if Certified then B.A.Converged else B.A.Exhausted),
         Outcome.Result'Image & " at" & Frac'Image);
      for I in W'Range loop
         Assert
           (abs (W (I) - Oracle (I)) <= Within,
            "weight" & I'Image & " at" & Frac'Image);
      end loop;
   end Check_Bucket;

   --  At Frac 32 the residuals' floor, about ten units or 2.3e-9, lies
   --  above the 1e-10 and 1e-9 that certify 1e-6, so the solve runs to
   --  its cap; its weights are within 1e-6 all the same.
   procedure Check_32 is new Check_Bucket (32, Certified => False);
   procedure Check_40 is new Check_Bucket (40, Certified => True);
   procedure Check_48 is new Check_Bucket (48, Certified => True);

   procedure Test_32 (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Check_32;
   end Test_32;

   procedure Test_40 (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Check_40;
   end Test_40;

   procedure Test_48 (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Check_48;
   end Test_48;

   overriding
   procedure Register_Tests (T : in out Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine (T, Test_32'Access, "The bucket's weights at Frac 32");
      Register_Routine (T, Test_40'Access, "The bucket's weights at Frac 40");
      Register_Routine (T, Test_48'Access, "The bucket's weights at Frac 48");
   end Register_Tests;

   overriding
   function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("Spike.Bucket");
   end Name;

end Spike_Bucket_Tests;
