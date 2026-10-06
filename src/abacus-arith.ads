--  Products and quotients on the grid, each rounded once to nearest
--  with ties away from zero.  A result that might not fit is formed at
--  128 bits and either proved to fit (Mul, Div), saturated and reported
--  (Mul_Sat, Div_Sat), or narrowed through the checked Store.

package Abacus.Arith
  with SPARK_Mode, Pure
is

   --  What may be rounded: a product of two values, or a value raised to
   --  the scale One * One, with room for the rounding bias.
   Product_Bound : constant := 2**126;
   subtype Product is Wide range -Product_Bound .. Product_Bound;

   --  What a quotient may be divided by: a pivot, a count, a count times
   --  One, or a power of ten.
   Divisor_Bound : constant := 2**96;
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

   --  A over B, rounded once to the grid.
   function Quotient_Of (A, B : Val) return Wide
   is (if B > 0
       then Div_Round (Wide (A) * One, Wide (B))
       else Div_Round (-(Wide (A) * One), -Wide (B)))
   with Pre => B /= 0;

   --  A times B, where the caller has shown that the product fits.
   function Mul (A, B : Val) return Val
   is (Val (Product_Of (A, B)))
   with Pre => Fits (Product_Of (A, B));

   --  A over B, where the caller has shown that the quotient fits.
   function Div (A, B : Val) return Val
   is (Val (Quotient_Of (A, B)))
   with Pre => B /= 0 and then Fits (Quotient_Of (A, B));

   --  How a saturating operation ended: in range, held at the largest
   --  value of its sign, or a quotient by zero.
   type Status is (Ok, Saturated, Undefined);

   type Checked is record
      Value  : Val := 0;
      Status : Arith.Status := Ok;
   end record;

   --  W held to the values, and whether it had to be.
   function Saturate (W : Wide) return Checked
   is ((Value  =>
          (if W > Wide (Val'Last)
           then Val'Last
           elsif W < Wide (Val'First)
           then Val'First
           else Val (W)),
        Status => (if Fits (W) then Ok else Saturated)));

   --  A times B, saturated inside the 128-bit product.
   function Mul_Sat (A, B : Val) return Checked
   is (Saturate (Product_Of (A, B)));

   --  A over B, saturated inside the 128-bit quotient; Undefined, with a
   --  value of zero, when B is zero.
   function Div_Sat (A, B : Val) return Checked
   is (if B = 0
       then (Value => 0, Status => Undefined)
       else Saturate (Quotient_Of (A, B)));

   --  W stored into V when it fits; Ok cleared, and V left as it was,
   --  when it does not.  Every narrowing in the library goes through it.
   procedure Store (W : Wide; V : in out Val; Ok : in out Boolean)
   with
     Post =>
       (if Fits (W)
        then Wide (V) = W and then Ok = Ok'Old
        else not Ok and then V = V'Old);

end Abacus.Arith;
