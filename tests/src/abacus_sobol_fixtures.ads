with Abacus;       use Abacus;
with Abacus.Sobol; use Abacus.Sobol;

--  The points and discrepancies tools/make_sobol.py wrote into
--  tests/data/sobol.txt.  Not SPARK: it reads a file.

package Abacus_Sobol_Fixtures is

   --  The first 64 unscrambled points in 64 dimensions, as scipy gives
   --  them.
   Plain_Points     : constant := 64;
   Plain_Dimensions : constant := 64;

   type Plain_Table is
     array (1 .. Plain_Points, 1 .. Plain_Dimensions) of Coordinate;

   function Plain return Plain_Table;

   --  The first 256 scrambled points in 8 dimensions for Seed, by the
   --  script's own implementation of the scramble.
   Seed                 : constant := 20261006;
   Scrambled_Points     : constant := 256;
   Scrambled_Dimensions : constant := 8;

   type Scrambled_Table is
     array (1 .. Scrambled_Points, 1 .. Scrambled_Dimensions) of Coordinate;

   function Scrambled return Scrambled_Table;

   --  L2-star discrepancies as values: scipy's of the scrambled points
   --  above, the mean and the largest of scipy's own scrambled points
   --  over 64 seeds, and the mean of uniform pseudo-random points.
   type Discrepancies is record
      Ours, Their_Mean, Their_Largest, Uniform_Mean : Val;
   end record;

   function Measured return Discrepancies;

end Abacus_Sobol_Fixtures;
