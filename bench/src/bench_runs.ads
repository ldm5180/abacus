with Abacus; use Abacus;

--  The measurements, one procedure per kernel.

package Bench_Runs is

   type Size_List is array (Positive range <>) of Index;

   Sizes : constant Size_List := [180, 3_000];

   --  Every measurement at one size.
   procedure Run_All (Profile : String; N : Index);

end Bench_Runs;
