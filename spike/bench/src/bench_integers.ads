with Spike; use Spike;

--  Representation (b), scaled integers: the dot product and the
--  factorization timed at one grid.

generic
   Frac : Frac_Bits;
package Bench_Integers is

   --  Repeats a dot product of two rows of length N; reports ns per term.
   procedure Time_Dot (N : Index; Repeats : Positive);

   procedure Time_Factor (N : Index);

   --  Repeats a rescaling multiply of each of N values by one value;
   --  reports ns per multiply.
   procedure Time_Mul (N : Index; Repeats : Positive);

end Bench_Integers;
