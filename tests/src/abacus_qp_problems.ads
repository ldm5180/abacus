with Abacus;    use Abacus;
with Abacus.Qp; use Abacus.Qp;

--  Small quadratic programs the solver's tests share: two variables
--  with the identity as P, in a box, with one row.  Not a library
--  unit's tests: the fixtures they are built from.

package Abacus_Qp_Problems is

   --  Minimize (1/2) x'x + Q'x with Lo <= x <= Hi and Row_Lo <= x1 + x2
   --  <= Row_Hi.
   function Two
     (Q : Vector := [0, 0]; Lo, Hi : Val := 0; Row_Lo, Row_Hi : Val := One)
      return Problem;

   --  Two with P given in place of the identity.
   function With_P (Pr : Problem; P : Matrix) return Problem
   with Pre => P'Length (1) = Pr.N and then P'Length (2) = Pr.N;

   --  Solve from St with S; the outcome.
   function Solved
     (Pr : Problem; S : Settings; St : in out State) return Outcome;

end Abacus_Qp_Problems;
