with Abacus; use Abacus;

--  The measurements, one procedure per kernel.

package Bench_Runs is

   type Size_List is array (Positive range <>) of Index;

   Sizes : constant Size_List := [180, 3_000];

   --  Every measurement at one size.
   procedure Run_All (Profile : String; N : Index);

   type Length_List is array (Positive range <>) of Positive;

   --  The lengths the sort is timed at: tables of millions of rows.
   Sort_Lengths : constant Length_List := [1_000_000, 4_000_000];

   --  The sort's order of N seeded values, ties by a seeded key.
   procedure Time_Sort (Profile : String; N : Positive);

end Bench_Runs;
