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
     (M : Matrix; I, J : Index; From : Positive; To : Count) return Dot_Sum
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
     (M : Matrix; I : Index; V : Vector; From : Positive; To : Count)
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

   --  Bit by bit from 2**56 down: R is the largest integer whose square
   --  is at most X, then one comparison rounds it to nearest.  R stays
   --  under 2**57 because its square is under 2**114; the clamp on the
   --  rounded result states that without a nonlinear proof.
   function Root (X : Root_Arg) return Val is
      R    : Wide := 0;
      Step : Wide := 2**56;
   begin
      for B in 0 .. 56 loop
         if (R + Step) * (R + Step) <= X then
            R := R + Step;
         end if;
         Step := Step / 2;
         pragma
           Loop_Invariant
             (R >= 0 and then Step >= 0 and then R + 2 * Step <= 2**57);
         pragma Loop_Invariant (R * R <= X);
      end loop;
      return Val (Wide'Min ((if X - R * R > R then R + 1 else R), Val_Bound));
   end Root;

end Spike.Kernels;
