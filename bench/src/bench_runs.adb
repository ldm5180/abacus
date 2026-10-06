with Ada.Real_Time; use Ada.Real_Time;
with Ada.Text_IO;
with Ada.Unchecked_Deallocation;

with Abacus.Cholesky;
with Abacus.Qp; use Abacus.Qp;
with Abacus.Qp.Engine;
with Abacus.Stats;
with Abacus.Vectors;

with Bench_Data; use Bench_Data;

package body Bench_Runs is

   --  The observations a rank update reads, a day of data each.
   Days : constant := 250;

   --  How many dot products are timed together, so one is measurable.
   Dot_Repeats : constant := 100_000;

   Per_Milli : constant := 1_000;

   --  A value the optimizer cannot discard, printed at the end of a size.
   Sink : Wide := 0;

   procedure Free is new Ada.Unchecked_Deallocation (Matrix, Matrix_Access);
   procedure Free is new Ada.Unchecked_Deallocation (Problem, Problem_Access);
   procedure Free is new
     Ada.Unchecked_Deallocation (Workspace, Workspace_Access);

   --  Thousandths, three figures with leading zeros.
   function Tail (Thousandths : Natural) return String is
      Image : constant String := Natural'Image (Thousandths + Per_Milli);
   begin
      return Image (Image'Last - 2 .. Image'Last);
   end Tail;

   function Millis (Span : Time_Span) return String is
      Micro : constant Integer :=
        Integer (To_Duration (Span) * Per_Milli * Per_Milli);
   begin
      return
        Integer'Image (Micro / Per_Milli) & "." & Tail (Micro mod Per_Milli);
   end Millis;

   procedure Report
     (Profile, What : String; N : Index; Span : Time_Span; Note : String := "")
   is
   begin
      Ada.Text_IO.Put_Line
        (Profile
         & ","
         & What
         & ","
         & N'Image
         & ","
         & Millis (Span)
         & ","
         & Note);
   end Report;

   procedure Time_Dot (Profile : String; N : Index) is
      A     : constant Matrix_Access := Returns (N, 2);
      X, Y  : Vector (1 .. N);
      Start : Time;
   begin
      for I in 1 .. N loop
         X (I) := A (I, 1);
         Y (I) := A (I, 2);
      end loop;
      Start := Clock;
      for K in 1 .. Dot_Repeats loop
         X (1) := X (1) + 1;
         Sink := Sink + Abacus.Vectors.Dot (X, Y);
      end loop;
      Report (Profile, "dot x" & Dot_Repeats'Image, N, Clock - Start);
   end Time_Dot;

   procedure Time_Rank_Update (Profile : String; N : Index) is
      Z       : Matrix_Access := Returns (N, Days);
      C       : Matrix_Access := new Matrix (1 .. N, 1 .. N);
      Outcome : Abacus.Stats.Estimate_Outcome;
      Start   : constant Time := Clock;
   begin
      Abacus.Stats.Correlate (Z.all, C.all, Outcome);
      Report
        (Profile,
         "rank update Z Z' over" & Days'Image & " days",
         N,
         Clock - Start,
         Outcome.Result'Image);
      Sink := Sink + Wide (C (N, 1));
      Free (Z);
      Free (C);
   end Time_Rank_Update;

   procedure Time_Factor_Solve (Profile : String; N : Index) is
      A       : Matrix_Access := Correlation (N);
      D       : Abacus.Cholesky.Pivots (1 .. N);
      B       : Vector (1 .. N) := [others => One];
      Outcome : Abacus.Cholesky.Factor_Outcome;
      Solved  : Abacus.Cholesky.Solve_Result;
      Start   : Time := Clock;
   begin
      Abacus.Cholesky.Factor (A.all, D, 1, Outcome);
      Report (Profile, "factor", N, Clock - Start, Outcome.Result'Image);
      Start := Clock;
      Abacus.Cholesky.Solve (A.all, D, B, Solved);
      Report (Profile, "solve", N, Clock - Start, Solved'Image);
      Sink := Sink + Wide (B (1));
      Free (A);
   end Time_Factor_Solve;

   procedure Time_Qp (Profile : String; N : Index) is
      Pr     : Problem_Access := Program (N);
      Work   : Workspace_Access := new Workspace (N);
      St     : State := Cold (N, 1);
      Result : Outcome;
      Start  : constant Time := Clock;
   begin
      Abacus.Qp.Engine.Solve (Pr.all, Default_Settings, Work.all, St, Result);
      Report
        (Profile,
         "qp",
         N,
         Clock - Start,
         Result'Image & St.Iterations'Image & " iterations");
      Sink := Sink + Wide (St.X (1));
      Free (Pr);
      Free (Work);
   end Time_Qp;

   procedure Run_All (Profile : String; N : Index) is
   begin
      Time_Dot (Profile, N);
      Time_Rank_Update (Profile, N);
      Time_Factor_Solve (Profile, N);
      Time_Qp (Profile, N);
      Ada.Text_IO.Put_Line ("# sink" & Sink'Image);
   end Run_All;

end Bench_Runs;
