--  Rounding from the 128-bit product scale back to one grid: the one
--  rounding a product or a sum of products takes.

generic
   Frac : Frac_Bits;
package Spike.Grid with SPARK_Mode, Pure is

   One  : constant Wide := 2**Frac;
   Half : constant Wide := One / 2;

   --  A value at scale One * One brought to scale One, rounded half away
   --  from zero.  The margin keeps the bias inside 128 bits.
   Product_Bound : constant := 2**126;
   subtype Product is Wide range -Product_Bound .. Product_Bound;

   function Round (A : Product) return Wide
   is (if A >= 0 then (A + Half) / One else -((-A + Half) / One))
   with
     Post =>
       Round'Result in (-Product_Bound) / One - 1 .. Product_Bound / One + 1;

   --  A product of two values, rounded once to the grid.
   function Mul (A, B : Val) return Wide
   is (Round (Wide (A) * Wide (B)));

end Spike.Grid;
