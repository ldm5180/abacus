with Ada.Real_Time; use Ada.Real_Time;
with Bench_Report;  use Bench_Report;
with Spike.Deltas;

package body Bench_Fixed is

   package F is new Spike.Deltas (Fix, Acc);
   use F;

   type Matrix_Access is access Fix_Matrix;

   --  Divisors kept out of static evaluation: a static quotient that is
   --  not a multiple of Small is a compile-time warning.
   Hundred : constant Integer := Integer'Value ("100");
   Three   : constant Integer := Integer'Value ("3");
   Seven   : constant Integer := Integer'Value ("7");

   --  A multiplier just under one.
   Near_One : constant Fix := 1.0 - Fix'Small * 1_000;

   procedure Fill_Blocks (M : in out Fix_Matrix) is
      Half : constant Index := M'Last (1) / 2;
   begin
      for I in M'Range (1) loop
         for J in M'Range (2) loop
            M (I, J) :=
              (if I = J
               then 1.0
               elsif (I <= Half) = (J <= Half)
               then Fix'(73.0) / Hundred
               else -(Fix'(26.0) / Hundred));
         end loop;
      end loop;
   end Fill_Blocks;

   procedure Time_Dot (N : Index; Repeats : Positive) is
      M     : Fix_Matrix (1 .. 2, 1 .. N);
      Start : Time;
      S     : Acc;
   begin
      for K in 1 .. N loop
         M (1, K) := Fix'(1.0) / Three + Fix'Small * K;
         M (2, K) := -Fix'(1.0) / Seven + Fix'Small * K;
      end loop;
      Start := Clock;
      for R in 1 .. Repeats loop
         M (1, 1 + R mod N) := M (1, 1 + R mod N) + Fix'Small;
         S := Dot (M, 1, 2, 1, N);
         Sink := Sink + (if S > 0.0 then 1 else 0);
      end loop;
      Report_Per ("dot ns per term (a)", Frac, N, Clock - Start, N * Repeats);
   end Time_Dot;

   procedure Time_Factor (N : Index) is
      M       : constant Matrix_Access := new Fix_Matrix (1 .. N, 1 .. N);
      D       : F.Pivots (1 .. N);
      Outcome : Outcome_Kind;
      Start   : Time;
   begin
      Fill_Blocks (M.all);
      Start := Clock;
      Factor (M.all, D, Fix'Small, Outcome);
      Report ("factor (a) " & Outcome'Image, Frac, N, Clock - Start);
   end Time_Factor;

   procedure Time_Mul (N : Index; Repeats : Positive) is
      V     : Fix_Vector (1 .. N) := [others => Fix'(1.0) / Three];
      S     : Fix := Near_One;
      Start : Time;
   begin
      Start := Clock;
      for R in 1 .. Repeats loop
         for I in V'Range loop
            V (I) := Fix (V (I) * S) + Fix'Small;
         end loop;
         S := S - Fix'Small;
      end loop;
      Report_Per ("mul ns (a)", Frac, N, Clock - Start, N * Repeats);
      Sink := Sink + (if V (N) > 0.0 then 1 else 0);
   end Time_Mul;

end Bench_Fixed;
