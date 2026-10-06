with Spike; use Spike;
with Spike.Bucket;

--  The bucket at one grid: the whole solve timed stage by stage, and the
--  iteration traced against the oracle's weights.

generic
   Frac : Frac_Bits;
package Bench_Bucket is

   package B is new Spike.Bucket (Frac);

   --  Estimate, factor and solve, each timed, best of Runs; then the
   --  whole Solve_Bucket.
   procedure Time_Bucket (S : B.A.Settings; Runs : Positive);

   --  Every Check_Every iterations up to Max_Iter: the residuals and the
   --  largest distance from the oracle's weights; prints the first
   --  iteration within 1e-6, where the solver's own rule stops, and the
   --  floor.
   procedure Trace (S : B.A.Settings; Label : String);

end Bench_Bucket;
