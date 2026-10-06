--  The numerics of the solver: ADMM in the operator-splitting form.  The
--  matrix P + sigma I + rho I + rho_row E'E is factored once; each
--  iteration solves with it, projects onto the bounds and updates the
--  duals.  Every step size is a power of two, so applying one is a
--  shift.  The checks between iterations: the residuals, the
--  infeasibility certificates, and whether the grid holds the iterate
--  still.

package Abacus.Qp.Admm
  with SPARK_Mode
is

   --  How forming and factoring ended: ready to iterate, P not positive
   --  semidefinite (P + sigma I would not factor), or a value past its
   --  range.
   type Prepare_Result is (Ready, Not_Convex, Out_Of_Range);

   procedure Prepare
     (Pr     : Problem;
      S      : Settings;
      Work   : out Workspace;
      Result : out Prepare_Result)
   with Pre => Work.N = Pr.N;

   --  One iteration; Ok is False when a value left its range.
   procedure Iterate
     (Pr   : Problem;
      S    : Settings;
      Work : Workspace;
      St   : in out State;
      Ok   : out Boolean)
   with Pre => Work.N = Pr.N and then Fits_State (Pr, St);

   --  The largest primal residual (x against z, E x against z_row) and
   --  the largest dual one (P x + Q + y + E'y_row), as values at most.
   type Residual is record
      Primal : Wide;
      Dual   : Wide;
   end record;

   function Residuals (Pr : Problem; St : State) return Residual
   with Pre => Fits_State (Pr, St);

   --  What a check between iterations found: the residuals within
   --  tolerance; the duals' change certifying no x meets the bounds; the
   --  iterate's change certifying the objective falls without end; the
   --  iterate the same as at the last check; or still moving.
   type Verdict is
     (Converged, Primal_Infeasible, Dual_Infeasible, Held, Moving);

   --  St checked against the tolerances and against Last, the state at
   --  the last check; Last becomes St when it is still moving.
   procedure Check
     (Pr   : Problem;
      S    : Settings;
      St   : State;
      Last : in out State;
      V    : out Verdict)
   with Pre => Fits_State (Pr, St) and then Fits_State (Pr, Last);

end Abacus.Qp.Admm;
