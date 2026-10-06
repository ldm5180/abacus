with Ada.Text_IO;
with Bench_Report;
with Bench_Runs;

--  Times the spike's kernels and its bucket at each grid, in both
--  representations, and traces the bucket's iteration against the
--  oracle.  Not SPARK: a harness around the units, with a clock, files
--  and the heap.

procedure Bench_Spike is
begin
   Bench_Runs.Trace_Buckets;
   Bench_Runs.Time_Buckets;
   Bench_Runs.Time_Kernels;
   Ada.Text_IO.Put_Line ("sink" & Bench_Report.Sink'Image);
end Bench_Spike;
