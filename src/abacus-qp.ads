--  A quadratic program and what solving one needs: minimize
--  (1/2) x'P x + Q'x subject to Lo <= x <= Hi and Row_Lo <= E x <= Row_Hi,
--  with P symmetric positive semidefinite.  The box rows are the
--  identity, so only the K general rows are stored.  A bound at the end
--  of the values is no bound: Val'First below, Val'Last above.  A run of
--  general rows may instead lie in a second-order cone, which makes the
--  problem a second-order cone program.  The solver is Abacus.Qp.Engine;
--  the certificate it is held to is Abacus.Qp.Certificate.

with Abacus.Cholesky;

package Abacus.Qp
  with SPARK_Mode
is

   No_Lower : constant Val := Val'First;
   No_Upper : constant Val := Val'Last;

   --  What a general row is held to.  Interval: Row_Lo .. Row_Hi.
   --  Cone_Head: it begins a second-order cone, which the Cone_Tail rows
   --  right after it continue; a Cone_Tail with no cone above it begins
   --  one.  The cone's rows of E x, less their Row_Lo (the cone's
   --  vertex), lie in {(s, u) : ||u|| <= s}, s the head's; Row_Hi is not
   --  read.  So ||G x + g|| <= h'x + h0 is a head row h' with Row_Lo
   --  -h0 and the rows of G with Row_Lo -g.
   type Row_Kind is (Interval, Cone_Head, Cone_Tail);
   type Row_Kinds is array (Index range <>) of Row_Kind;

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
      Kind   : Row_Kinds (1 .. K) := [others => Interval];
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

   --  A step size for each of a run of rows or variables.
   type Shifts is array (Index range <>) of Shift;

   --  A scale, 2**Scale_Shift: a variable's, or the cost's.
   subtype Scale_Shift is Integer range -64 .. 64;
   type Scale_Shifts is array (Index range <>) of Scale_Shift;

   subtype Iteration_Cap is Positive range 1 .. 1_000_000;
   subtype Check_Interval is Positive range 1 .. 1_000;

   --  The relaxation, between one and two.
   subtype Relaxation is Val range One .. 2 * One - 1;

   --  How many iterations apart a polish is tried; zero never.
   subtype Polish_Interval is Natural range 0 .. Iteration_Cap'Last;

   --  How many corrections of the bounds it holds a polish makes.
   subtype Correction_Count is Natural range 0 .. 1_000;

   --  How many passes an equilibration makes.
   subtype Pass_Count is Natural range 0 .. 64;

   --  The steps on the box rows, on the general rows, and of the
   --  proximal term; the relaxation; the iteration cap; how often the
   --  residuals and the infeasibility certificates are checked; the
   --  tolerances; the infeasibility test's ratio, 2**-Infeasible; and
   --  the polish: tried at a check whose iteration count is a multiple of
   --  Polish_Every, when both residuals are within Polish_Below, and
   --  correcting the bounds it holds up to Corrections times; and how
   --  many passes of equilibration set each row's and variable's step
   --  from the three shifts (Abacus.Qp.Scaling), zero for none.
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
      Corrections  : Correction_Count;
      Equilibrate  : Pass_Count;
   end record;

   --  The settings S0 measured on a problem in correlation space: rho 1,
   --  rho_row 2**3, sigma 2**-20, alpha 1.6, and tolerances of 1e-10
   --  (primal) and 1e-9 (dual and complementarity).  A small rho_row
   --  keeps the general rows' duals on a fine lattice.  A polish every
   --  100 iterations whatever the residuals, making up to 32 corrections:
   --  an iterate's held bounds can be near the answer's while its
   --  residuals are far from any threshold.
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
      Polish_Below => Nonnegative'Last,
      Corrections  => 32,
      Equilibrate  => 0);

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

   --  What a solve works in, held by the caller so a large problem's need
   --  not live on the stack: the iteration's matrix, equilibrated and
   --  factored, its steps and scales, and the general rows by step; and
   --  the polish's -- the bounds it holds, the free variables and held
   --  rows (the first Free_Count and Row_Count of Free_At and Row_At), E's
   --  held rows over the free columns (A), A'A + delta P + delta**2 I and
   --  A A' + delta**2 I factored in their leading blocks, and the bounds
   --  it last failed from.
   type Workspace
     (N : Index;
      K : Count)
   is record
      L          : Matrix (1 .. N, 1 .. N);
      D          : Cholesky.Pivots (1 .. N);
      Box_Step   : Shifts (1 .. N);
      Row_Step   : Shifts (1 .. K);
      Prox_Step  : Shifts (1 .. N);
      Row_Order  : Places (1 .. K);
      Var_Scale  : Scale_Shifts (1 .. N);
      Cost_Scale : Scale_Shift;
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
      Tried      : Boolean;
      Tried_Box  : Sides (1 .. N);
      Tried_Row  : Sides (1 .. K);
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
