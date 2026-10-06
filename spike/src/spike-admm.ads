--  A quadratic program solved by ADMM in the operator-splitting form, on
--  one grid: the matrix P + sigma I + rho A'A is factored once, and each
--  iteration solves with it, projects onto the bounds, and updates the
--  duals.  Every step size is a power of two, so applying one is a shift.

generic
   Frac : Frac_Bits;
package Spike.Admm with SPARK_Mode is

   --  Minimize (1/2) x'P x + Q'x subject to Lo <= x <= Hi and
   --  Row_Lo <= E x <= Row_Hi, every value at scale One.  The box rows
   --  are the identity, so only the K general rows are stored.
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

   --  A step size, 2**Shift.
   subtype Shift is Integer range -30 .. 30;

   --  The step on the box rows, on the general rows, and the proximal
   --  term; the relaxation (at scale One); the iteration cap; how often
   --  the residuals are checked; and their tolerances (raw).
   type Settings is record
      Rho_Shift   : Shift;
      Row_Shift   : Shift;
      Sigma_Shift : Shift;
      Alpha       : Val;
      Max_Iter    : Positive;
      Check_Every : Positive;
      Tol_Primal  : Val;
      Tol_Dual    : Val;
   end record;

   --  The iterate: x, the projected box rows z and their duals y, the
   --  same for the general rows, and the iterations taken.
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

   --  Converged: both residuals within tolerance.  Stalled: the iterate
   --  did not change between two checks, so the grid holds it where it
   --  is.  Exhausted: the cap was reached first.  Diverged: a value left
   --  its range.  Not_Positive_Definite: the matrix would not factor.
   type Result_Kind is
     (Converged, Stalled, Exhausted, Diverged, Not_Positive_Definite);

   --  The matrix the iteration solves with, factored.
   type Factored (N : Index) is record
      L : Matrix (1 .. N, 1 .. N);
      D : Pivots (1 .. N);
   end record;

   --  How forming and factoring the matrix ended.
   type Prepare_Result is (Ready, Out_Of_Range, Not_Positive_Definite);

   procedure Prepare
     (Pr     : Problem;
      S      : Settings;
      F      : out Factored;
      Result : out Prepare_Result)
   with Pre => F.N = Pr.N;

   --  One iteration; Ok is False when a value left its range.
   procedure Iterate
     (Pr : Problem;
      S  : Settings;
      F  : Factored;
      St : in out State;
      Ok : out Boolean)
   with Pre => F.N = Pr.N and then St.N = Pr.N and then St.K = Pr.K;

   --  The largest primal residual (x against z, E x against z_row) and
   --  the largest dual one (P x + Q + y + E'y_row), raw.
   type Residual is record
      Primal : Wide;
      Dual   : Wide;
   end record;

   function Residuals (Pr : Problem; St : State) return Residual
   with Pre => St.N = Pr.N and then St.K = Pr.K;

   --  Prepare, then iterate from St until converged, stalled or capped.
   procedure Solve
     (Pr : Problem; S : Settings; St : in out State; Result : out Result_Kind)
   with Pre => St.N = Pr.N and then St.K = Pr.K;

end Spike.Admm;
