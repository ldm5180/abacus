with Ada.Real_Time;
with Spike;

--  One CSV line per measurement: profile, what, grid, size, milliseconds.

package Bench_Report is

   procedure Report
     (What : String; Frac, Size : Natural; Span : Ada.Real_Time.Time_Span);

   --  The same, for a cost per operation: Span over Ops, in nanoseconds.
   procedure Report_Per
     (What       : String;
      Frac, Size : Natural;
      Span       : Ada.Real_Time.Time_Span;
      Ops        : Positive);

   --  A value the optimizer cannot discard, printed once at the end.
   Sink : Spike.Wide := 0;

end Bench_Report;
