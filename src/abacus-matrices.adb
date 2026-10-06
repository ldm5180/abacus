with Abacus.Arith; use Abacus.Arith;

package body Abacus.Matrices
  with SPARK_Mode
is

   --  One term of a dot product, at most Term_Bound in magnitude.
   function Term (A, B : Val) return Wide
   is (Wide (A) * Wide (B))
   with Post => Term'Result in -Term_Bound .. Term_Bound;

   function Row_Dot
     (M : Matrix; I, J : Index; From : Positive; To : Count) return Dot_Sum
   is
      Acc : Wide := 0;
   begin
      for K in From .. To loop
         Acc := Acc + Term (M (I, K), M (J, K));
         pragma
           Loop_Invariant
             (Acc
              in -Sum_Bound (K - From + 1, Term_Bound)
               .. Sum_Bound (K - From + 1, Term_Bound));
      end loop;
      return Acc;
   end Row_Dot;

   function Row_Vector_Dot
     (M : Matrix; I : Index; V : Vector; From : Positive; To : Count)
      return Dot_Sum
   is
      Acc : Wide := 0;
   begin
      for K in From .. To loop
         Acc := Acc + Term (M (I, K), V (K));
         pragma
           Loop_Invariant
             (Acc
              in -Sum_Bound (K - From + 1, Term_Bound)
               .. Sum_Bound (K - From + 1, Term_Bound));
      end loop;
      return Acc;
   end Row_Vector_Dot;

   function Column_Dot (M : Matrix; I, J : Index) return Dot_Sum is
      Acc : Wide := 0;
   begin
      for R in M'Range (1) loop
         Acc := Acc + Term (M (R, I), M (R, J));
         pragma
           Loop_Invariant
             (Acc
              in -Sum_Bound (R - M'First (1) + 1, Term_Bound)
               .. Sum_Bound (R - M'First (1) + 1, Term_Bound));
      end loop;
      return Acc;
   end Column_Dot;

   function Column_Vector_Dot
     (M : Matrix; I : Index; V : Vector) return Dot_Sum
   is
      Acc : Wide := 0;
   begin
      for R in M'Range (1) loop
         Acc := Acc + Term (M (R, I), V (R));
         pragma
           Loop_Invariant
             (Acc
              in -Sum_Bound (R - M'First (1) + 1, Term_Bound)
               .. Sum_Bound (R - M'First (1) + 1, Term_Bound));
      end loop;
      return Acc;
   end Column_Vector_Dot;

   procedure Multiply
     (A : Matrix; X : Vector; Y : out Vector; Ok : out Boolean) is
   begin
      Y := [others => 0];
      Ok := True;
      for I in A'Range (1) loop
         Store
           (Round_Shift (Row_Vector_Dot (A, I, X, A'First (2), A'Last (2))),
            Y (I),
            Ok);
      end loop;
   end Multiply;

   procedure Gram (X : Matrix; G : out Matrix; Ok : out Boolean) is
   begin
      G := [others => [others => 0]];
      Ok := True;
      for I in X'Range (2) loop
         for J in X'First (2) .. I loop
            Store (Round_Shift (Column_Dot (X, I, J)), G (I, J), Ok);
         end loop;
      end loop;
      Mirror (G);
   end Gram;

   procedure Mirror (A : in out Matrix) is
   begin
      for I in A'Range (1) loop
         for J in A'First (1) .. I - 1 loop
            A (J, I) := A (I, J);
         end loop;
      end loop;
   end Mirror;

end Abacus.Matrices;
