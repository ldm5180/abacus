with Spike; use Spike;

--  Representation (a), Ada fixed-point types: the dot product and the
--  factorization timed at one grid.

generic
   type Fix is delta <>;
   type Acc is delta <>;
   Frac : Frac_Bits;
package Bench_Fixed is

   procedure Time_Dot (N : Index; Repeats : Positive);

   procedure Time_Factor (N : Index);

   --  As Bench_Integers.Time_Mul: Ada's own fixed-point multiply, the
   --  product converted back to Fix.
   procedure Time_Mul (N : Index; Repeats : Positive);

end Bench_Fixed;
