with Ada.Real_Time; use Ada.Real_Time;
with Bench_Report;  use Bench_Report;
with Spike.Grid;
with Spike.Kernels;
with Spike.Linear;

package body Bench_Integers is

   package L is new Spike.Linear (Frac);
   package G is new Spike.Grid (Frac);

   type Matrix_Access is access Matrix;

   One : constant Raw := 2**Frac;

   --  The bench matrix's correlations: 0.73 within a block, -0.26
   --  between; and a multiplier just under one.
   Within_Block  : constant Raw := One / 100 * 73;
   Between_Block : constant Raw := -(One / 100 * 26);
   Near_One      : constant Raw := One - One / 1_000_000;
   Low_Bits      : constant := 1_024;

   --  Two blocks of half the size each: 0.73 within a block, -0.26
   --  between, one on the diagonal; positive definite at any size.
   procedure Fill_Blocks (M : in out Matrix) is
      Half : constant Index := M'Last (1) / 2;
   begin
      for I in M'Range (1) loop
         for J in M'Range (2) loop
            M (I, J) :=
              (if I = J
               then One
               elsif (I <= Half) = (J <= Half)
               then Within_Block
               else Between_Block);
         end loop;
      end loop;
   end Fill_Blocks;

   procedure Time_Dot (N : Index; Repeats : Positive) is
      M     : Matrix (1 .. 2, 1 .. N);
      Start : Time;
   begin
      for K in 1 .. N loop
         M (1, K) := One / 3 + Raw (K);
         M (2, K) := -One / 7 + Raw (K);
      end loop;
      Start := Clock;
      for R in 1 .. Repeats loop
         M (1, 1 + R mod N) := M (1, 1 + R mod N) + 1;
         Sink := Sink + Spike.Kernels.Dot (M, 1, 2, 1, N) mod Low_Bits;
      end loop;
      Report_Per ("dot ns per term (b)", Frac, N, Clock - Start, N * Repeats);
   end Time_Dot;

   procedure Time_Factor (N : Index) is
      M       : constant Matrix_Access := new Matrix (1 .. N, 1 .. N);
      D       : Pivots (1 .. N);
      Outcome : L.Factor_Outcome;
      Start   : Time;
   begin
      Fill_Blocks (M.all);
      Start := Clock;
      L.Factor (M.all, D, 1, Outcome);
      Report ("factor (b) " & Outcome.Result'Image, Frac, N, Clock - Start);
   end Time_Factor;

   procedure Time_Mul (N : Index; Repeats : Positive) is
      V     : Vector (1 .. N) := [others => One / 3];
      S     : Val := Near_One;
      Start : Time;
   begin
      Start := Clock;
      for R in 1 .. Repeats loop
         for I in V'Range loop
            V (I) := Val (G.Mul (V (I), S)) + 1;
         end loop;
         S := S - 1;
      end loop;
      Report_Per ("mul ns (b)", Frac, N, Clock - Start, N * Repeats);
      Sink := Sink + Wide (V (N));
   end Time_Mul;

end Bench_Integers;
