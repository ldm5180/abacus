with Spike; use Spike;

--  The bucket's fixture files, as written by tools/make_bucket.py: raw
--  integers at one grid.  Paths are relative to spike/.  Not SPARK: it
--  reads files.

package Fixtures is

   Assets : constant := 180;
   Days   : constant := 250;
   Block  : constant := 90;

   --  The returns, one row per asset and one column per day.
   function Returns (Frac : Natural) return Matrix
   with
     Post =>
       Returns'Result'First (1) = 1
       and then Returns'Result'Last (1) = Assets
       and then Returns'Result'First (2) = 1
       and then Returns'Result'Last (2) = Days;

   --  The oracle's weights.
   function Weights (Frac : Natural) return Vector;

   --  Row 1 the oracle's means, row 2 its standard deviations, rows 3
   --  and 4 the first and last rows of its correlation matrix.
   function Moments (Frac : Natural) return Matrix;

end Fixtures;
