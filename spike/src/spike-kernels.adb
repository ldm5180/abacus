package body Spike.Kernels
  with SPARK_Mode
is

   --  One term of a dot product, at most Term_Bound in magnitude.
   function Term (A, B : Val) return Wide
   is (Wide (A) * Wide (B))
   with Post => Term'Result in -Term_Bound .. Term_Bound;

   --  The bound on a sum of Len terms.
   function Sum_Bound (Len : Count) return Wide
   is (Wide (Len) * Term_Bound);

   function Dot
     (M : Matrix; I, J : Index; From : Index; To : Count) return Dot_Sum
   is
      Acc : Wide := 0;
   begin
      for K in From .. To loop
         Acc := Acc + Term (M (I, K), M (J, K));
         pragma
           Loop_Invariant
             (Acc in -Sum_Bound (K - From + 1) .. Sum_Bound (K - From + 1));
      end loop;
      return Acc;
   end Dot;

   function Dot
     (M : Matrix; I : Index; V : Vector; From : Index; To : Count)
      return Dot_Sum
   is
      Acc : Wide := 0;
   begin
      for K in From .. To loop
         Acc := Acc + Term (M (I, K), V (K));
         pragma
           Loop_Invariant
             (Acc in -Sum_Bound (K - From + 1) .. Sum_Bound (K - From + 1));
      end loop;
      return Acc;
   end Dot;

end Spike.Kernels;
