with Abacus.Qp.Certificate;

--  The polish: the bounds an iterate holds are read off it, the problem
--  is solved with those bounds held as equalities, and the answer is
--  kept only when it is certified.  ADMM settles which bounds hold long
--  before it meets the tolerances, and on a linear program, whose answer
--  is a vertex, it creeps; the polish turns that tail into a few solves.
--  The solves go through the Cholesky factorization: the held rows by a
--  regularized system refined against the exact one, finer than the
--  grid, their multipliers by least squares.  A cone is curved, and
--  cannot be held as an equality: its rows are never held, and a problem
--  with one is not polished.

package Abacus.Qp.Polish
  with SPARK_Mode
is

   --  Work's sides read off St, OSQP's rule: a bound is held when the
   --  constraint lies nearer to it than its multiplier pulls toward it.
   --  An equality row is always held; an open bound never, nor a cone's
   --  row.
   procedure Read_Held (Pr : Problem; St : State; Work : in out Workspace)
   with Pre => Fits_Work (Pr, Work) and then Fits_State (Pr, St);

   --  The problem solved with Work's sides held, from From: each held
   --  variable at its bound; the free variables from the equality-
   --  constrained problem; the held rows' multipliers by least squares,
   --  and the held variables' from the gradient.  Ok is False when a
   --  value left its range or a factorization was refused.
   procedure Solve_Held
     (Pr   : Problem;
      Work : in out Workspace;
      From : State;
      Cand : out State;
      Ok   : out Boolean)
   with
     Pre =>
       Fits_Work (Pr, Work)
       and then Fits_State (Pr, From)
       and then Cand.N = Pr.N
       and then Cand.K = Pr.K;

   --  One correction of Work's sides from Cand: the held bound whose
   --  multiplier pushes hardest the wrong way is released; failing one,
   --  the free constraint Cand lies furthest outside is held at the bound
   --  it passes.  Changed is False when there was neither.
   procedure Correct
     (Pr      : Problem;
      Cand    : State;
      Work    : in out Workspace;
      Changed : out Boolean)
   with Pre => Fits_Work (Pr, Work) and then Fits_State (Pr, Cand);

   --  How many corrections a polish makes before it gives up.
   Max_Corrections : constant := 4;

   --  St polished: Passed when the problem solved with the bounds St
   --  holds, or with up to Max_Corrections corrections of them, is
   --  certified, and St is then that answer; otherwise St is as it was.
   --  A problem with a cone is not polished.
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

end Abacus.Qp.Polish;
