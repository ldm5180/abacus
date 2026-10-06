--  A quadratic program and what solving one needs: minimize
--  (1/2) x'P x + Q'x subject to Lo <= x <= Hi and Row_Lo <= E x <= Row_Hi,
--  with P symmetric positive semidefinite.  The box rows are the
--  identity, so only the K general rows are stored.  A bound at the end
--  of the values is no bound: Val'First below, Val'Last above.  The
--  solver is Abacus.Qp.Engine; the certificate it is held to is
--  Abacus.Qp.Certificate.

with Abacus.Cholesky;

package Abacus.Qp
  with SPARK_Mode
is

   No_Lower : constant Val := Val'First;
   No_Upper : constant Val := Val'Last;

   type Problem
     (N : Index;
      K : Count)
   is record
      P      : Matrix (1 .. N, 1 .. N);
      Q      : Vector (1 .. N);
      Lo     : Vector (1 .. N);
      Hi     : Vector (1 .. N);
      E      : Matrix (1 .. K, 1 .. N);
      Row_Lo : Vector (1 .. K);
      Row_Hi : Vector (1 .. K);
   end record;

   subtype Nonnegative is Val range 0 .. Val'Last;

   --  What a certified answer is held to: its primal residual (how far
   --  x and E x lie outside their bounds), its dual residual (the size
   --  of P x + Q + y + E'y_row) and its complementarity (a multiplier
   --  times the slack of its bound), each as a value.
   type Tolerance is record
      Primal : Nonnegative;
      Dual   : Nonnegative;
      Gap    : Nonnegative;
   end record;

   --  A step size, 2**Shift.
   subtype Shift is Integer range -30 .. 30;

   subtype Iteration_Cap is Positive range 1 .. 1_000_000;
   subtype Check_Interval is Positive range 1 .. 1_000;

   --  The relaxation, between one and two.
   subtype Relaxation is Val range One .. 2 * One - 1;

   --  How many iterations apart a polish is tried; zero never.
   subtype Polish_Interval is Natural range 0 .. Iteration_Cap'Last;

   --  The steps on the box rows, on the general rows, and of the
   --  proximal term; the relaxation; the iteration cap; how often the
   --  residuals and the infeasibility certificates are checked; the
   --  tolerances; the infeasibility test's ratio, 2**-Infeasible; and
   --  the polish: tried at a check whose iteration count is a multiple of
   --  Polish_Every, when both residuals are within Polish_Below.
   type Settings is record
      Rho_Shift    : Shift;
      Row_Shift    : Shift;
      Sigma_Shift  : Shift;
      Alpha        : Relaxation;
      Max_Iter     : Iteration_Cap;
      Check_Every  : Check_Interval;
      Tol          : Tolerance;
      Infeasible   : Natural range 0 .. Frac;
      Polish_Every : Polish_Interval;
      Polish_Below : Nonnegative;
   end record;

   --  The settings S0 measured on a problem in correlation space: rho 1,
   --  rho_row 2**3, sigma 2**-20, alpha 1.6, and tolerances of 1e-10
   --  (primal) and 1e-9 (dual and complementarity).  A small rho_row
   --  keeps the general rows' duals on a fine lattice.  A polish every
   --  100 iterations once both residuals are within 1e-3.
   Default_Settings : constant Settings :=
     (Rho_Shift    => 0,
      Row_Shift    => 3,
      Sigma_Shift  => -20,
      Alpha        => One * 8 / 5,
      Max_Iter     => 4_000,
      Check_Every  => 10,
      Tol          =>
        (Primal => One / 10_000_000_000,
         Dual   => One / 1_000_000_000,
         Gap    => One / 1_000_000_000),
      Infeasible   => 16,
      Polish_Every => 100,
      Polish_Below => One / 1_000);

   --  The iterate: x, the projected box rows z and their duals y, the
   --  same for the general rows, and the iterations taken.  A state
   --  passed back in is a warm start.
   type State
     (N : Index;
      K : Count)
   is record
      X          : Vector (1 .. N);
      Z          : Vector (1 .. N);
      Y          : Vector (1 .. N);
      Z_Row      : Vector (1 .. K);
      Y_Row      : Vector (1 .. K);
      Iterations : Natural;
   end record;

   --  A state of zeros.
   function Cold (N : Index; K : Count) return State
   is ((N          => N,
        K          => K,
        X | Z | Y  => [others => 0],
        Z_Row      => [others => 0],
        Y_Row      => [others => 0],
        Iterations => 0));

   --  Which of its bounds a constraint is held at, if either.
   type Side is (Free, At_Lower, At_Upper);
   type Sides is array (Index range <>) of Side;

   --  Places in a vector: the polish's maps from its packed systems back
   --  to the problem's variables and rows.
   type Places is array (Index range <>) of Index;

   --  What a solve works in, held by the caller so that a large
   --  problem's need not live on the stack: the matrix the iteration
   --  solves with, factored; and the polish's -- the bounds it holds,
   --  the free variables and held rows in order (Free_At, Row_At, the
   --  first Free_Count and Row_Count of each), E's held rows over the
   --  free columns packed into A, and the two matrices it solves with,
   --  A'A + delta P + delta**2 I and A A' + delta**2 I, factored in their
   --  leading blocks.
   type Workspace
     (N : Index;
      K : Count)
   is record
      L          : Matrix (1 .. N, 1 .. N);
      D          : Cholesky.Pivots (1 .. N);
      Box_Side   : Sides (1 .. N);
      Row_Side   : Sides (1 .. K);
      Free_At    : Places (1 .. N);
      Row_At     : Places (1 .. K);
      Free_Count : Count;
      Row_Count  : Count;
      A          : Matrix (1 .. K, 1 .. N);
      S          : Matrix (1 .. N, 1 .. N);
      S_D        : Cholesky.Pivots (1 .. N);
      G          : Matrix (1 .. K, 1 .. K);
      G_D        : Cholesky.Pivots (1 .. K);
   end record;

   function Fits_Work (Pr : Problem; Work : Workspace) return Boolean
   is (Work.N = Pr.N and then Work.K = Pr.K);

   --  How a solve ended.  Certified: the answer meets every tolerance.
   --  Infeasible: the duals certify that no x meets the bounds.
   --  Unbounded: a direction certifies the objective falls without end.
   --  Not_Convex: P is not positive semidefinite.  Stalled: the grid
   --  holds the iterate still short of the tolerances.  Exhausted: the
   --  cap came first.  Diverged: a value left its range.
   type Outcome is
     (Certified,
      Infeasible,
      Unbounded,
      Not_Convex,
      Stalled,
      Exhausted,
      Diverged);

   function Fits_State (Pr : Problem; St : State) return Boolean
   is (St.N = Pr.N and then St.K = Pr.K);

end Abacus.Qp;
