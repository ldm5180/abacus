with Abacus.Qp.Certificate;

--  The crossover: from the bounds an iterate holds to an optimal vertex
--  of a linear program, by the simplex method on the held set.  ADMM's
--  held set is a few bounds from the answer's long before ADMM can tell
--  them apart, and at a near-degenerate vertex the polish's corrections,
--  one bound at a time, wander; pivots do not.  The held set is first
--  made a basis (square, its held rows independent over its free
--  columns); the cost is shifted until every held multiplier has its
--  sign, and the dual simplex method walks to a feasible vertex; the
--  shift is then taken back and the primal simplex method walks to the
--  optimal one, by Dantzig's rule, by Bland's after a step of no length.
--  Each vertex is the held system solved exactly (Abacus.Qp.Held), and an
--  answer is kept only when it is certified.

package Abacus.Qp.Crossover
  with SPARK_Mode
is

   --  Whether Pr is a linear program: no quadratic term.
   function Is_Linear (Pr : Problem) return Boolean
   is (for all I in 1 .. Pr.N => (for all J in 1 .. Pr.N => Pr.P (I, J) = 0));

   --  St crossed over to a vertex: Passed when one is reached, within
   --  S.Pivots pivots, that is certified, and St is then that answer;
   --  otherwise St is as it was.  A problem with a quadratic term or a
   --  cone is not crossed over.  Work is a prepared workspace.
   procedure Run
     (Pr     : Problem;
      S      : Settings;
      Work   : in out Workspace;
      St     : in out State;
      Passed : out Boolean)
   with
     Pre  => Fits_Work (Pr, Work) and then Fits_State (Pr, St),
     Post =>
       (if Passed then Certificate.Certified (Pr, St, S.Tol) else St = St'Old);

end Abacus.Qp.Crossover;
