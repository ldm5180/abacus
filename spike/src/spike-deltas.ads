--  Representation (a)'s kernels: the dot product, root, Cholesky factor
--  and triangular solves of Spike.Kernels and Spike.Linear, written over
--  Ada fixed-point types so the two can be timed and proved side by side.

generic
   type Fix is delta <>;
   type Acc is delta <>;
package Spike.Deltas with SPARK_Mode is

   type Fix_Vector is array (Index range <>) of Fix;
   type Fix_Matrix is array (Index range <>, Index range <>) of Fix;

   --  A pivot is positive by its subtype, as Spike.Pivot is.
   subtype Pivot is Fix range Fix'Small .. Fix'Last;
   type Pivots is array (Index range <>) of Pivot;

   type Outcome_Kind is (Done, Not_Positive_Definite, Out_Of_Range);

   --  The bound on one product of two values, and on a sum of Max_N.
   Term_Max : constant Acc := Acc (Fix'Last * Fix'Last);

   --  The instance's accumulator holds a dot product of Max_N terms with
   --  a value added: what every kernel below assumes.
   function Roomy return Boolean
   is (Term_Max * Max_N <= Acc'Last - Acc (Fix'Last));

   function Sum_Max (Len : Count) return Acc
   is (Term_Max * Len)
   with Pre => Roomy;

   function Dot
     (M : Fix_Matrix; I, J : Index; From : Positive; To : Count) return Acc
   with
     Pre  =>
       Roomy
       and then I in M'Range (1)
       and then J in M'Range (1)
       and then (if From <= To
                 then From >= M'First (2) and then To <= M'Last (2)),
     Post => Dot'Result in -Sum_Max (Max_N) .. Sum_Max (Max_N);

   function Dot
     (M : Fix_Matrix; I : Index; V : Fix_Vector; From : Positive; To : Count)
      return Acc
   with
     Pre  =>
       Roomy
       and then I in M'Range (1)
       and then (if From <= To
                 then
                   From >= M'First (2)
                   and then To <= M'Last (2)
                   and then From >= V'First
                   and then To <= V'Last),
     Post => Dot'Result in -Sum_Max (Max_N) .. Sum_Max (Max_N);

   --  The nearest value to the square root of X.
   function Root (X : Acc) return Fix
   with Pre => Roomy and then X >= 0.0 and then X < Term_Max;

   function Is_Square (A : Fix_Matrix) return Boolean
   is (A'First (1) = A'First (2) and then A'Last (1) = A'Last (2));

   --  As Spike.Linear.Factor: in place, D the pivots, mirrored.
   procedure Factor
     (A       : in out Fix_Matrix;
      D       : out Pivots;
      Floor   : Pivot;
      Outcome : out Outcome_Kind)
   with
     Pre =>
       Roomy
       and then Is_Square (A)
       and then D'First = A'First (1)
       and then D'Last = A'Last (1);

   --  As Spike.Linear.Solve.
   procedure Solve
     (L       : Fix_Matrix;
      D       : Pivots;
      B       : in out Fix_Vector;
      Outcome : out Outcome_Kind)
   with
     Pre =>
       Roomy
       and then Is_Square (L)
       and then D'First = L'First (1)
       and then D'Last = L'Last (1)
       and then B'First = L'First (1)
       and then B'Last = L'Last (1);

end Spike.Deltas;
