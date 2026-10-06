--  Dense symmetric linear algebra on one grid: the Cholesky factorization
--  and the two triangular solves.

generic
   Frac : Frac_Bits;
package Spike.Linear with SPARK_Mode is

   type Factor_Result is (Factored, Not_Positive_Definite, Out_Of_Range);

   --  How a factorization ended, and the column it ended at (zero when it
   --  factored).
   type Factor_Outcome is record
      Result : Factor_Result;
      Column : Count;
   end record;

   function Is_Square (A : Matrix) return Boolean
   is (A'First (1) = A'First (2) and then A'Last (1) = A'Last (2));

   --  A = L L', in place.  Reads the lower triangle of A; on Factored the
   --  strict lower triangle holds L, the upper its mirror, and D (and the
   --  diagonal) L's diagonal.  A pivot under Floor is refused.
   procedure Factor
     (A       : in out Matrix;
      D       : out Pivots;
      Floor   : Pivot;
      Outcome : out Factor_Outcome)
   with
     Pre =>
       Is_Square (A)
       and then D'First = A'First (1)
       and then D'Last = A'Last (1);

end Spike.Linear;
