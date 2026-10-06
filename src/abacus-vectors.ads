with Abacus.Arith;

--  Vectors of values: dot products and sums accumulated exactly at 128
--  bits and rounded once, so the order of the terms cannot matter;
--  norms; and axpy and scaling through the checked store.

package Abacus.Vectors
  with SPARK_Mode
is

   --  The largest product of two values, and so the bound on one term
   --  of a dot product.
   Term_Bound : constant := 2**(2 * Val_Bits);

   --  The bound on any exact dot product: Max_N terms of Term_Bound.
   Dot_Bound : constant := Max_N * Term_Bound;
   subtype Dot_Sum is Wide range -Dot_Bound .. Dot_Bound;

   --  The bound on a sum of Len terms of at most Bound each.
   function Sum_Bound (Len : Count; Bound : Wide) return Wide
   is (Wide (Len) * Bound)
   with Pre => Bound in 0 .. Term_Bound;

   --  The sum of A (I) * B (I), exact, at scale One * One.
   function Dot_Exact (A, B : Vector) return Dot_Sum
   with
     Pre  => A'Length = B'Length,
     Post =>
       Dot_Exact'Result
       in -Sum_Bound (A'Length, Term_Bound)
        .. Sum_Bound (A'Length, Term_Bound);

   --  The dot product, rounded once to the grid.  Its magnitude is at
   --  most the length times 2**74, the largest product of two values.
   function Dot (A, B : Vector) return Wide
   is (Arith.Round_Shift (Dot_Exact (A, B)))
   with Pre => A'Length = B'Length;

   --  The sum of A, exact.
   function Sum (A : Vector) return Wide
   with
     Post =>
       Sum'Result
       in -Sum_Bound (A'Length, Val_Bound) .. Sum_Bound (A'Length, Val_Bound);

   subtype Nonnegative is Val range 0 .. Val'Last;

   --  The largest magnitude in A; zero for an empty vector.
   function Norm_Inf (A : Vector) return Nonnegative
   with Post => (for all I in A'Range => abs A (I) <= Norm_Inf'Result);

   --  Y := Y + Alpha X, each entry rounded once and stored through the
   --  checked store: an entry that would leave the values clears Ok and
   --  keeps its old value.
   procedure Axpy
     (Alpha : Val; X : Vector; Y : in out Vector; Ok : out Boolean)
   with Pre => X'Length = Y'Length;

   --  X := Alpha X, likewise.
   procedure Scale (Alpha : Val; X : in out Vector; Ok : out Boolean);

end Abacus.Vectors;
