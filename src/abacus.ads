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

end Abacus;
