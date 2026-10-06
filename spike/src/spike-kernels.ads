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

end Spike.Kernels;
