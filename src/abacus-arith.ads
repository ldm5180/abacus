--  Products on the grid, each rounded once to nearest with ties away
--  from zero.  A product is formed at 128 bits and proved to fit before
--  it is narrowed.

package Abacus.Arith
  with SPARK_Mode, Pure
is

   --  What may be rounded: a product of two values, or a value raised to
   --  the scale One * One, with room for the rounding bias.
   Product_Bound : constant := 2**126;
   subtype Product is Wide range -Product_Bound .. Product_Bound;

   --  What a quotient may be divided by: a pivot, a count, or a count
   --  times One.
   Divisor_Bound : constant := 2**64;
   subtype Divisor is Wide range 1 .. Divisor_Bound;

   --  N / D rounded to nearest, ties away from zero: the one rounding
   --  every operation here takes.
   function Div_Round (N : Product; D : Divisor) return Wide
   is (if N >= 0 then (N + D / 2) / D else -((-N + D / 2) / D))
   with
     Post =>
       (if N >= 0
        then Div_Round'Result in 0 .. N
        else Div_Round'Result in N .. 0);

   --  A value at scale One * One brought to scale One.
   Shifted_Bound : constant := Product_Bound / One + 1;

   function Round_Shift (A : Product) return Wide
   is (Div_Round (A, One))
   with Post => Round_Shift'Result in -Shifted_Bound .. Shifted_Bound;

   --  Whether a wide result can be stored as a value.
   function Fits (W : Wide) return Boolean
   is (W in Wide (Val'First) .. Wide (Val'Last));

   --  A times B, rounded once to the grid.
   function Product_Of (A, B : Val) return Wide
   is (Round_Shift (Wide (A) * Wide (B)));

   --  A times B, where the caller has shown that the product fits.
   function Mul (A, B : Val) return Val
   is (Val (Product_Of (A, B)))
   with Pre => Fits (Product_Of (A, B));

end Abacus.Arith;
