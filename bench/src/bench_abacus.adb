with Ada.Command_Line;
with Ada.Text_IO;

with Bench_Runs;

--  Times the kernels and the solver at 180 and 3,000 variables and
--  prints CSV: what, size, milliseconds, and a note.  The profile name
--  on the command line heads each line.

procedure Bench_Abacus is
   Profile : constant String :=
     (if Ada.Command_Line.Argument_Count >= 1
      then Ada.Command_Line.Argument (1)
      else "release");
begin
   Ada.Text_IO.Put_Line ("profile,what,size,ms,note");
   for Size of Bench_Runs.Sizes loop
      Bench_Runs.Run_All (Profile, Size);
   end loop;
end Bench_Abacus;
