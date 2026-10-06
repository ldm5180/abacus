--  The certificates a solve is held to, computed at 128 bits and rounded
--  once per entry.  Certified: the answer's primal residual, dual
--  residual and complementarity are each within their tolerance.
--  Infeasible: a change in the duals that no x can answer.  Unbounded:
--  a change in x along which the objective falls and every bound holds.

with Abacus.Arith;
with Abacus.Matrices;

package Abacus.Qp.Certificate
  with SPARK_Mode
is

   --  A rounded row or product: at most Max_N times 2**74 and a little.
   Grid_Bound : constant := 2**90;
   subtype Grid is Wide range -Grid_Bound .. Grid_Bound;

   --  How far A lies outside [Lo, Hi]; zero inside.
   function Outside (A : Grid; Lo, Hi : Val) return Wide
   is (if A > Wide (Hi)
       then A - Wide (Hi)
       elsif A < Wide (Lo)
       then Wide (Lo) - A
       else 0)
   with Post => Outside'Result >= 0;

   --  Row R of E times V, rounded once.
   function Row_Of (Pr : Problem; R : Index; V : Vector) return Grid
   is (Arith.Round_Shift (Matrices.Row_Vector_Dot (Pr.E, R, V, 1, Pr.N)))
   with Pre => R <= Pr.K and then V'First = 1 and then V'Last = Pr.N;

   --  |W| for a W that is not the most negative Wide.
   function Magnitude (W : Wide) return Wide
   is (if W < 0 then -W else W)
   with Pre => W > Wide'First;

   --  How far x lies outside its box and E x outside its rows' bounds,
   --  at most.
   function Primal_Residual (Pr : Problem; St : State) return Wide
   with Pre => Fits_State (Pr, St), Post => Primal_Residual'Result >= 0;

   --  The size of P x + Q + y + E'y_row, the gradient of the Lagrangian.
   function Dual_Residual (Pr : Problem; St : State) return Wide
   with Pre => Fits_State (Pr, St), Post => Dual_Residual'Result >= 0;

   --  The largest multiplier times the slack of the bound it holds: a
   --  positive y belongs to an upper bound, a negative one to a lower.
   --  Against an open bound a multiplier must be zero, and counts whole.
   function Complementarity (Pr : Problem; St : State) return Wide
   with Pre => Fits_State (Pr, St), Post => Complementarity'Result >= 0;

   function Certified
     (Pr : Problem; St : State; Tol : Tolerance) return Boolean
   is (Primal_Residual (Pr, St) <= Wide (Tol.Primal)
       and then Dual_Residual (Pr, St) <= Wide (Tol.Dual)
       and then Complementarity (Pr, St) <= Wide (Tol.Gap))
   with Pre => Fits_State (Pr, St);

   --  The least change, in units, that a certificate of infeasibility is
   --  read from: a smaller one is the grid's noise.
   Least_Change : constant := 2**20;

   --  Whether the duals' change from Last to St certifies that no x
   --  meets the bounds: A'dy within 2**-Ratio of the change, and the
   --  bounds' support of dy below minus that.
   function Infeasible
     (Pr : Problem; St, Last : State; Ratio : Natural) return Boolean
   with
     Pre =>
       Fits_State (Pr, St)
       and then Fits_State (Pr, Last)
       and then Ratio <= Frac;

   --  Whether x's change from Last to St certifies that the objective
   --  falls without end: P dx and every bounded row of dx within
   --  2**-Ratio of the change, and Q'dx below minus that.
   function Unbounded
     (Pr : Problem; St, Last : State; Ratio : Natural) return Boolean
   with
     Pre =>
       Fits_State (Pr, St)
       and then Fits_State (Pr, Last)
       and then Ratio <= Frac;

end Abacus.Qp.Certificate;
