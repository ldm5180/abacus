with Bench_Bucket;
with Bench_Fixed;
with Bench_Integers;
with Spike.Delta_Types; use Spike.Delta_Types;

package body Bench_Runs is

   Large       : constant := 3_000;
   Bucket      : constant := 180;
   Dot_Repeats : constant := 100_000;
   Mul_Repeats : constant := 100_000;
   Trace_Cap   : constant := 2_000;
   Runs        : constant := 5;

   package I32 is new Bench_Integers (32);
   package I40 is new Bench_Integers (40);
   package I48 is new Bench_Integers (48);
   package F32 is new Bench_Fixed (Fix_32, Acc_32, 32);
   package F40 is new Bench_Fixed (Fix_40, Acc_40, 40);
   package F48 is new Bench_Fixed (Fix_48, Acc_48, 48);
   package B32 is new Bench_Bucket (32);
   package B40 is new Bench_Bucket (40);
   package B48 is new Bench_Bucket (48);

   type Shift_List is array (Positive range <>) of Integer;

   --  The rho_row exponents traced.
   Row_Shifts : constant Shift_List := [2, 3, 4, 6, 8, 10];

   procedure Trace_Buckets is
   begin
      B32.Trace (B32.B.Default_Settings, "default");
      B40.Trace (B40.B.Default_Settings, "default");
      B48.Trace (B48.B.Default_Settings, "default");
      B32.Trace (B32.B.Default_Settings, "default", Scaled => False);
      B40.Trace (B40.B.Default_Settings, "default", Scaled => False);
      B48.Trace (B48.B.Default_Settings, "default", Scaled => False);
      for Row of Row_Shifts loop
         B32.Trace
           ((B32.B.Default_Settings
             with delta Row_Shift => Row, Max_Iter => Trace_Cap),
            "row" & Row'Image);
         B40.Trace
           ((B40.B.Default_Settings
             with delta Row_Shift => Row, Max_Iter => Trace_Cap),
            "row" & Row'Image);
         B48.Trace
           ((B48.B.Default_Settings
             with delta Row_Shift => Row, Max_Iter => Trace_Cap),
            "row" & Row'Image);
      end loop;
   end Trace_Buckets;

   procedure Time_Buckets is
   begin
      B32.Time_Stages (B32.B.Default_Settings, Runs);
      B40.Time_Stages (B40.B.Default_Settings, Runs);
      B48.Time_Stages (B48.B.Default_Settings, Runs);
      B32.Time_Bucket (B32.B.Default_Settings, Runs);
      B40.Time_Bucket (B40.B.Default_Settings, Runs);
      B48.Time_Bucket (B48.B.Default_Settings, Runs);
   end Time_Buckets;

   procedure Time_Kernels is
   begin
      I40.Time_Mul (Bucket, Mul_Repeats);
      F40.Time_Mul (Bucket, Mul_Repeats);
      I40.Time_Dot (Large, Dot_Repeats);
      F40.Time_Dot (Large, Dot_Repeats);
      I32.Time_Factor (Bucket);
      I40.Time_Factor (Bucket);
      I48.Time_Factor (Bucket);
      F32.Time_Factor (Bucket);
      F40.Time_Factor (Bucket);
      F48.Time_Factor (Bucket);
      I32.Time_Factor (Large);
      I40.Time_Factor (Large);
      I48.Time_Factor (Large);
      F32.Time_Factor (Large);
      F40.Time_Factor (Large);
      F48.Time_Factor (Large);
   end Time_Kernels;

end Bench_Runs;
