--  Square root, exp, log, the standard normal CDF and its inverse, on
--  the grid.  Each takes its domain as a subtype.  Root and Sqrt round
--  exactly; Exp and Log work at 2**-60 inside and round once, so each
--  is within a unit of the grid value nearest the true one (relative to
--  the result, for an Exp above one); the normal CDF and its inverse
--  are rational approximations whose stated errors are their own.

package Abacus.Elementary
  with SPARK_Mode
is

   --  What Root takes: a value at scale One * One, or any integer whose
   --  root is wanted, below 2**114.
   Root_Bits : constant := 2 * Val_Bits;
   subtype Root_Arg is Wide range 0 .. 2**Root_Bits - 1;

   --  The integer nearest the square root of X.  An argument at scale
   --  One * One gives a root at scale One.
   function Root (X : Root_Arg) return Val
   with Post => Root'Result >= 0;

   subtype Nonnegative is Val range 0 .. Val'Last;

   --  The square root, rounded to nearest.
   function Sqrt (X : Nonnegative) return Nonnegative;

   --  Exp's domain: below Exp_Floor the result is under half a unit and
   --  reads as zero; Exp_Ceiling (11.75) keeps the result a value.
   Exp_Floor   : constant := -30 * One;
   Exp_Ceiling : constant := 47 * One / 4;

   subtype Exp_Arg is Val range Val'First .. Exp_Ceiling;

   function Exp (X : Exp_Arg) return Nonnegative;

   --  Log's domain: every positive value.
   subtype Log_Arg is Val range 1 .. Val'Last;

   function Log (X : Log_Arg) return Val;

   subtype Probability is Val range 0 .. One;

   --  The standard normal CDF by Abramowitz and Stegun 26.2.17, whose
   --  error is under 7.5e-8 everywhere.
   function Norm_Cdf (X : Val) return Probability;

   --  The open unit interval, the inverse CDF's domain.
   subtype Open_Probability is Val range 1 .. One - 1;

   --  The standard normal quantile by Wichura's AS 241 (PPND16), a
   --  rational approximation good to about 1e-16 in binary64; on this
   --  grid it is within a few units of the grid value nearest the true
   --  one (the tests state the bound).
   function Inv_Norm_Cdf (P : Open_Probability) return Val;

end Abacus.Elementary;
