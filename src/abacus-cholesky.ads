with Abacus.Matrices;

--  The Cholesky factorization A = L L' of a symmetric matrix, in place,
--  the two triangular solves that use it, and least squares through the
--  normal equations.  A pivot under the caller's floor is refused and
--  its column named; every entry of L is checked into range before it
--  is stored, so the next column's proof has its bound.

package Abacus.Cholesky
  with SPARK_Mode
is

   --  A pivot of a factorization: positive, so it can be divided by.
   subtype Pivot is Val range 1 .. Val'Last;
   type Pivots is array (Index range <>) of Pivot;

   type Factor_Result is (Factored, Not_Positive_Definite, Out_Of_Range);

   --  How a factorization ended, and the column it ended at (zero when it
   --  factored).
   type Factor_Outcome is record
      Result : Factor_Result;
      Column : Count;
   end record;

   --  A = L L', in place.  Reads the lower triangle of A; on Factored the
   --  strict lower triangle holds L, the upper its mirror, and D (and the
   --  diagonal) L's diagonal.  A pivot under Floor is refused.
   procedure Factor
     (A       : in out Matrix;
      D       : out Pivots;
      Floor   : Pivot;
      Outcome : out Factor_Outcome)
   with
     Pre  =>
       Matrices.Is_Square (A)
       and then D'First = A'First (1)
       and then D'Last = A'Last (1),
     Post =>
       (if Outcome.Result = Factored
        then Outcome.Column = 0
        else Outcome.Column in A'Range (1));

   type Solve_Result is (Solved, Out_Of_Range);

   --  L L' x = B, in place: the forward solve, then the back solve, with
   --  L and D as Factor leaves them.  Each entry is checked into range as
   --  it is stored; one past it ends the solve.
   procedure Solve
     (L : Matrix; D : Pivots; B : in out Vector; Result : out Solve_Result)
   with
     Pre =>
       Matrices.Is_Square (L)
       and then D'First = L'First (1)
       and then D'Last = L'Last (1)
       and then B'First = L'First (1)
       and then B'Last = L'Last (1);

   --  The Beta that minimizes |X Beta - Y|**2 + Ridge |Beta|**2, from
   --  (X'X + Ridge I) Beta = X'Y.  A Gram matrix whose pivots fall to a
   --  unit is Not_Positive_Definite at that column; an entry past the
   --  values is Out_Of_Range.
   procedure Least_Squares
     (X       : Matrix;
      Y       : Vector;
      Ridge   : Val;
      Beta    : out Vector;
      Outcome : out Factor_Outcome)
   with
     Pre  =>
       X'Length (1) <= Max_N
       and then X'First (2) = 1
       and then X'Last (2) >= 1
       and then Y'First = X'First (1)
       and then Y'Last = X'Last (1)
       and then Beta'First = 1
       and then Beta'Last = X'Last (2),
     Post =>
       (if Outcome.Result = Factored
        then Outcome.Column = 0
        else Outcome.Column in 1 .. X'Last (2));

end Abacus.Cholesky;
