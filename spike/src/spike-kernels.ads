--  Dot products accumulated exactly at 128 bits: no rounding, so the
--  order of the terms cannot matter.  The caller rounds once.

package Spike.Kernels
  with SPARK_Mode, Pure
is

   --  The sum over columns From .. To of M (I, K) * M (J, K); zero when
   --  the range is empty.
   function Dot
     (M : Matrix; I, J : Index; From : Index; To : Count) return Dot_Sum
   with
     Pre =>
       I in M'Range (1)
       and then J in M'Range (1)
       and then (if From <= To
                 then From >= M'First (2) and then To <= M'Last (2));

   --  The sum over K in From .. To of M (I, K) * V (K); zero when the
   --  range is empty.
   function Dot
     (M : Matrix; I : Index; V : Vector; From : Index; To : Count)
      return Dot_Sum
   with
     Pre =>
       I in M'Range (1)
       and then (if From <= To
                 then
                   From >= M'First (2)
                   and then To <= M'Last (2)
                   and then From >= V'First
                   and then To <= V'Last);

   --  The nearest integer to the square root of X.  An argument at scale
   --  One * One gives a root at scale One.
   subtype Root_Arg is Wide range 0 .. Term_Bound - 1;

   function Root (X : Root_Arg) return Val
   with Post => Root'Result >= 0;

   --  A dot product less a value at scale One, for every grid: the
   --  numerator of every quotient a kernel takes.
   Numerator_Bound : constant := Dot_Bound + 2**110;
   subtype Numerator is Wide range -Numerator_Bound .. Numerator_Bound;

   --  S / D rounded half away from zero.
   function Div_Round (S : Numerator; D : Pivot) return Wide
   is (if S >= 0
       then (S + Wide (D) / 2) / Wide (D)
       else -((-S + Wide (D) / 2) / Wide (D)));

end Spike.Kernels;
