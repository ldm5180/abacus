with Ada.Command_Line;
with Ada.Real_Time; use Ada.Real_Time;
with Ada.Text_IO;   use Ada.Text_IO;
with Spike;         use Spike;
with Spike.Linear;

--  Times the spike's kernels at each grid and prints one line per
--  measurement: profile, what, grid, size, milliseconds.  Not SPARK: it
--  is a harness around the units, with a clock and the heap.

procedure Bench_Spike is

   Profile : constant String :=
     (if Ada.Command_Line.Argument_Count >= 1
      then Ada.Command_Line.Argument (1)
      else "unknown");

   type Matrix_Access is access Matrix;

   Large : constant := 3_000;

   function Millis (Span : Time_Span) return Duration
   is (To_Duration (Span) * 1_000);

   procedure Report (What : String; Frac, Size : Natural; Span : Time_Span) is
   begin
      Put_Line
        (Profile
         & ","
         & What
         & ","
         & Frac'Image
         & ","
         & Size'Image
         & ","
         & Duration'Image (Millis (Span)));
   end Report;

   --  Two blocks of half the size each: 0.73 within a block, -0.26
   --  between, one on the diagonal; positive definite at any size.
   procedure Fill_Blocks (M : in out Matrix; One : Raw) is
      Half : constant Index := M'Last (1) / 2;
   begin
      for I in M'Range (1) loop
         for J in M'Range (2) loop
            M (I, J) :=
              (if I = J
               then One
               elsif (I <= Half) = (J <= Half)
               then One / 100 * 73
               else -(One / 100 * 26));
         end loop;
      end loop;
   end Fill_Blocks;

   generic
      Frac : Frac_Bits;
   procedure Time_Factor (N : Index);

   procedure Time_Factor (N : Index) is
      package L is new Spike.Linear (Frac);
      M       : Matrix_Access := new Matrix (1 .. N, 1 .. N);
      D       : Pivots (1 .. N);
      Outcome : L.Factor_Outcome;
      Start   : Time;
   begin
      Fill_Blocks (M.all, 2**Frac);
      Start := Clock;
      L.Factor (M.all, D, 1, Outcome);
      Report ("factor " & Outcome.Result'Image, Frac, N, Clock - Start);
      pragma Unreferenced (M);
   end Time_Factor;

   procedure Factor_32 is new Time_Factor (32);
   procedure Factor_40 is new Time_Factor (40);
   procedure Factor_48 is new Time_Factor (48);

begin
   Factor_32 (180);
   Factor_40 (180);
   Factor_48 (180);
   Factor_32 (Large);
   Factor_40 (Large);
   Factor_48 (Large);
end Bench_Spike;
