with Abacus;    use Abacus;
with Abacus.Qp; use Abacus.Qp;

--  The benchmark's inputs, made from a seeded generator: returns, and a
--  problem in correlation space from a factor model (unit diagonal,
--  entries in -1 .. 1), so its matrix is well conditioned at any size.

package Bench_Data is

   type Matrix_Access is access Matrix;
   type Problem_Access is access Problem;
   type Workspace_Access is access Workspace;

   --  Returns of N series over Days observations, each about 0.05 wide.
   function Returns (N : Index; Days : Positive) return Matrix_Access;

   --  The correlation of a five-factor model over N series, plus a ridge.
   function Correlation (N : Index) return Matrix_Access;

   --  Minimize (1/2) x'P x + q'x over the correlation, each x in
   --  0 .. 0.05 and their sum exactly one.
   function Program (N : Index) return Problem_Access;

end Bench_Data;
