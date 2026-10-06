with Ada.Text_IO;
with Bench_Bucket;
with Bench_Fixed;
with Bench_Integers;
with Bench_Report;
with Spike.Delta_Types; use Spike.Delta_Types;

--  Times the spike's kernels at each grid in both representations.  Not
--  SPARK: it is a harness around the units, with a clock and the heap.

procedure Bench_Spike is

   Large : constant := 3_000;

   package I32 is new Bench_Integers (32);
   package I40 is new Bench_Integers (40);
   package I48 is new Bench_Integers (48);
   package F32 is new Bench_Fixed (Fix_32, Acc_32, 32);
   package F40 is new Bench_Fixed (Fix_40, Acc_40, 40);
   package F48 is new Bench_Fixed (Fix_48, Acc_48, 48);

   Dot_Repeats : constant := 100_000;

   type Shift_List is array (Positive range <>) of Integer;

   --  The rho_row exponents traced.
   Row_Shifts : constant Shift_List := [2, 3, 4, 6, 8, 10];

   package B32 is new Bench_Bucket (32);
   package B40 is new Bench_Bucket (40);
   package B48 is new Bench_Bucket (48);

begin
   for Row of Row_Shifts loop
      B32.Trace
        ((B32.B.Default_Settings
          with delta Row_Shift => Row, Max_Iter => 2_000),
         "row" & Row'Image);
      B40.Trace
        ((B40.B.Default_Settings
          with delta Row_Shift => Row, Max_Iter => 2_000),
         "row" & Row'Image);
      B48.Trace
        ((B48.B.Default_Settings
          with delta Row_Shift => Row, Max_Iter => 2_000),
         "row" & Row'Image);
   end loop;
   B32.Time_Bucket (B32.B.Default_Settings, 5);
   B40.Time_Bucket (B40.B.Default_Settings, 5);
   B48.Time_Bucket (B48.B.Default_Settings, 5);
   I40.Time_Dot (Large, Dot_Repeats);
   F40.Time_Dot (Large, Dot_Repeats);
   I32.Time_Factor (180);
   I40.Time_Factor (180);
   I48.Time_Factor (180);
   F32.Time_Factor (180);
   F40.Time_Factor (180);
   F48.Time_Factor (180);
   I32.Time_Factor (Large);
   I40.Time_Factor (Large);
   I48.Time_Factor (Large);
   F32.Time_Factor (Large);
   F40.Time_Factor (Large);
   F48.Time_Factor (Large);
   Ada.Text_IO.Put_Line ("sink" & Bench_Report.Sink'Image);
end Bench_Spike;
