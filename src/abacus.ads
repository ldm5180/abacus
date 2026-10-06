--  Fixed-point numerics: a value is a 64-bit integer counting units of
--  2**(-Frac), and a product is formed in a 128-bit integer and rounded
--  once.  No floating-point type appears anywhere in the crate.

package Abacus
  with SPARK_Mode, Pure
is

   --  The grid: a value counts units of 2**(-Frac).
   Frac : constant := 40;

   --  The value one, in units.
   One : constant := 2**Frac;

   --  A value, in units of the grid.
   type Raw is range -2**63 .. 2**63 - 1 with Size => 64;

   --  A product or a sum of products, before it is rounded to the grid.
   type Wide is range -2**127 .. 2**127 - 1 with Size => 128;

   --  Every stored value's magnitude is at most 2**57 units: a product of
   --  two is then at most 2**114, and a sum of Max_N products stays under
   --  2**127.  At this grid that is about 131,000.
   Val_Bits  : constant := 57;
   Val_Bound : constant := 2**Val_Bits;

   --  A value as it is stored.
   subtype Val is Raw range -Val_Bound .. Val_Bound;

   --  A value whose magnitude is at most one: a correlation, a
   --  standardized direction, a weight.
   subtype Unit_Raw is Val range -One .. One;

   --  The longest vector or matrix side the library accepts.
   Max_N : constant := 4_096;

   subtype Count is Natural range 0 .. Max_N;
   subtype Index is Positive range 1 .. Max_N;

   type Vector is array (Index range <>) of Val;
   type Matrix is array (Index range <>, Index range <>) of Val;

end Abacus;
