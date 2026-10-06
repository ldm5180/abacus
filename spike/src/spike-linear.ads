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

   type Solve_Result is (Solved, Out_Of_Range);

   --  L L' x = B, in place: the forward solve, then the back solve, with
   --  L and D as Factor leaves them.  Each entry is checked into range as
   --  it is stored; one past it ends the solve.
   procedure Solve
     (L : Matrix; D : Pivots; B : in out Vector; Result : out Solve_Result)
   with
     Pre =>
       Is_Square (L)
       and then D'First = L'First (1)
       and then D'Last = L'Last (1)
       and then B'First = L'First (1)
       and then B'Last = L'Last (1);

end Spike.Linear;
