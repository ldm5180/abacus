--  The S0 spike's shared vocabulary: a value is a 64-bit integer counting
--  units of 2**(-Frac), a product is formed in a 128-bit integer, and the
--  arrays the kernels work over.  Frac is a generic parameter of the
--  child packages, so one build measures every grid.

package Spike
  with SPARK_Mode, Pure
is

   type Raw is range -2**63 .. 2**63 - 1 with Size => 64;
   type Wide is range -2**127 .. 2**127 - 1 with Size => 128;

   --  The longest vector or matrix side a kernel accepts.
   Max_N : constant := 4_096;

   subtype Count is Natural range 0 .. Max_N;
   subtype Index is Positive range 1 .. Max_N;

   --  Every stored value's raw magnitude is at most 2**57, whatever the
   --  grid: a product of two is then at most 2**114 and a sum of Max_N
   --  products stays under 2**127.  At Frac 40 that is about 131,000.
   Val_Bits  : constant := 57;
   Val_Bound : constant := 2**Val_Bits;

   subtype Val is Raw range -Val_Bound .. Val_Bound;

   type Vector is array (Index range <>) of Val;
   type Matrix is array (Index range <>, Index range <>) of Val;

   --  The largest product of two values, and so the bound on one term
   --  of a dot product.
   Term_Bound : constant := 2**(2 * Val_Bits);

   --  The bound on any dot product: Max_N terms of Term_Bound.
   Dot_Bound : constant := Max_N * Term_Bound;
   subtype Dot_Sum is Wide range -Dot_Bound .. Dot_Bound;

   --  The grids the spike measures, and the widest it allows.
   subtype Frac_Bits is Natural range 16 .. 52;

end Spike;
