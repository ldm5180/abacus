with Abacus.Vectors; use Abacus.Vectors;

--  Dense matrices of values, row-major, with their bounds carried by the
--  array: the exact dot kernels every factorization and product is built
--  from, products with a vector, Gram matrices, and the mirror that
--  makes a lower triangle symmetric.  A sum of products is exact at 128
--  bits until it is rounded once.

package Abacus.Matrices
  with SPARK_Mode
is

   function Is_Square (A : Matrix) return Boolean
   is (A'First (1) = A'First (2) and then A'Last (1) = A'Last (2));

   --  The sum over columns From .. To of M (I, K) * M (J, K); zero when
   --  the span is empty.
   function Row_Dot
     (M : Matrix; I, J : Index; From : Positive; To : Count) return Dot_Sum
   with
     Pre =>
       I in M'Range (1)
       and then J in M'Range (1)
       and then (if From <= To
                 then From >= M'First (2) and then To <= M'Last (2));

   --  The sum over K in From .. To of M (I, K) * V (K); zero when the
   --  span is empty.
   function Row_Vector_Dot
     (M : Matrix; I : Index; V : Vector; From : Positive; To : Count)
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

   --  The sum over rows R of M (R, I) * M (R, J): two columns.
   function Column_Dot (M : Matrix; I, J : Index) return Dot_Sum
   with
     Pre =>
       I in M'Range (2)
       and then J in M'Range (2)
       and then M'Length (1) <= Max_N;

   --  The sum over rows R of M (R, I) * V (R).
   function Column_Vector_Dot
     (M : Matrix; I : Index; V : Vector) return Dot_Sum
   with
     Pre =>
       I in M'Range (2)
       and then V'First = M'First (1)
       and then V'Last = M'Last (1);

   --  Y = A X, each entry rounded once and stored through the checked
   --  store.
   procedure Multiply
     (A : Matrix; X : Vector; Y : out Vector; Ok : out Boolean)
   with
     Pre =>
       A'Length (2) >= 1
       and then X'First = A'First (2)
       and then X'Last = A'Last (2)
       and then Y'First = A'First (1)
       and then Y'Last = A'Last (1);

   --  G = X' X, each entry rounded once; G is symmetric.
   procedure Gram (X : Matrix; G : out Matrix; Ok : out Boolean)
   with
     Pre =>
       X'Length (1) <= Max_N
       and then G'First (1) = X'First (2)
       and then G'Last (1) = X'Last (2)
       and then G'First (2) = X'First (2)
       and then G'Last (2) = X'Last (2);

   --  The upper triangle from the lower.
   procedure Mirror (A : in out Matrix)
   with Pre => Is_Square (A);

end Abacus.Matrices;
