package body Abacus.Vectors
  with SPARK_Mode
is

   --  One term of a dot product, at most Term_Bound in magnitude.
   function Term (A, B : Val) return Wide
   is (Wide (A) * Wide (B))
   with Post => Term'Result in -Term_Bound .. Term_Bound;

   function Dot_Exact (A, B : Vector) return Dot_Sum is
      Acc : Wide := 0;
   begin
      for K in 0 .. A'Length - 1 loop
         Acc := Acc + Term (A (A'First + K), B (B'First + K));
         pragma
           Loop_Invariant
             (Acc
              in -Sum_Bound (K + 1, Term_Bound)
               .. Sum_Bound (K + 1, Term_Bound));
      end loop;
      return Acc;
   end Dot_Exact;

   function Sum (A : Vector) return Wide is
      Acc : Wide := 0;
   begin
      for K in 0 .. A'Length - 1 loop
         Acc := Acc + Wide (A (A'First + K));
         pragma
           Loop_Invariant
             (Acc
              in -Sum_Bound (K + 1, Val_Bound)
               .. Sum_Bound (K + 1, Val_Bound));
      end loop;
      return Acc;
   end Sum;

   function Norm_Inf (A : Vector) return Nonnegative is
      Largest : Nonnegative := 0;
   begin
      for I in A'Range loop
         if abs A (I) > Largest then
            Largest := abs A (I);
         end if;
         pragma
           Loop_Invariant (for all J in A'First .. I => abs A (J) <= Largest);
      end loop;
      return Largest;
   end Norm_Inf;

   procedure Axpy
     (Alpha : Val; X : Vector; Y : in out Vector; Ok : out Boolean) is
   begin
      Ok := True;
      for K in 0 .. X'Length - 1 loop
         Arith.Store
           (Wide (Y (Y'First + K)) + Arith.Product_Of (Alpha, X (X'First + K)),
            Y (Y'First + K),
            Ok);
      end loop;
   end Axpy;

   procedure Scale (Alpha : Val; X : in out Vector; Ok : out Boolean) is
   begin
      Ok := True;
      for I in X'Range loop
         Arith.Store (Arith.Product_Of (Alpha, X (I)), X (I), Ok);
      end loop;
   end Scale;

end Abacus.Vectors;
