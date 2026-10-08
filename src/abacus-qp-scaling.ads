--  Equilibration, as step sizes.  Ruiz's method scales a problem's
--  variables, rows and cost by powers of two until every column and row
--  of its optimality system has a largest entry near one.  ADMM on the
--  scaled problem is ADMM on the problem as posed with a step for each
--  row, rho times the square of the row's scale over the cost's, and a
--  proximal term for each variable, sigma over the cost's scale and the
--  square of the variable's: so the problem is never scaled, and no
--  entry of it is rounded, only the steps are set.

package Abacus.Qp.Scaling
  with SPARK_Mode
is

   --  The largest exponent a value may have, as a value: Val'Last is
   --  2**Most.
   Most : constant := Val_Bits - Frac;

   subtype Exponent is Integer range -Frac .. Most;

   --  The exponent of V's magnitude as a value: the largest E with 2**E
   --  at most |V|.  A unit is -Frac, One is zero.
   function Exponent_Of (V : Val) return Exponent
   with Pre => V /= 0;

   --  Work's steps for Pr: S's three shifts, equilibrated by
   --  S.Equilibrate passes, none above the setting's; a cone's rows share
   --  one step.  The variables' and the cost's scales, which equilibrate
   --  the matrix the iteration factors.  And the general rows in the order
   --  of their steps, each step's rows in their own order.
   procedure Set_Steps (Pr : Problem; S : Settings; Work : in out Workspace)
   with Pre => Fits_Work (Pr, Work);

end Abacus.Qp.Scaling;
