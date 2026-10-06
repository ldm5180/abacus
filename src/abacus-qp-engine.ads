with Abacus.Qp.Certificate;

--  The solver's loop, an sml machine: it decides what to do next --
--  prepare, iterate, check, polish, certify -- from what the last
--  request found,
--  and Solve carries the requests out.  The iteration cap bounds the
--  loop, so a solve ends; a Certified outcome is held to its
--  certificate by Solve's postcondition.

package Abacus.Qp.Engine
  with SPARK_Mode
is

   --  What the loop asks for next.
   type Command is (Prepare, Step, Check, Polish, Certify, Stop);

   --  The machine's states: one per request it waits on, and one per
   --  outcome.
   type Phase is
     (Preparing,
      Iterating,
      Checking,
      Polishing,
      Certifying,
      Certified,
      Infeasible,
      Unbounded,
      Not_Convex,
      Stalled,
      Exhausted,
      Diverged);

   subtype Final is Phase range Certified .. Diverged;

   --  What a request found, posted back to the machine: P is not
   --  positive semidefinite (Indefinite), the iterate near enough to
   --  polish, the certificate passed or not.
   type Event_Kind is
     (E_Ready,
      E_Indefinite,
      E_Out_Of_Range,
      E_Stepped,
      E_Converged,
      E_Primal_Infeasible,
      E_Dual_Infeasible,
      E_Held,
      E_Near,
      E_Moving,
      E_Passed,
      E_Not_Passed);

   --  The machine's context: the request it makes, what the last one
   --  found, and what its guards read -- the iterations taken, the cap,
   --  and how often to check.
   type Context is record
      Request     : Command := Prepare;
      Found       : Event_Kind := E_Ready;
      Iterations  : Natural := 0;
      Max_Iter    : Iteration_Cap := 1;
      Check_Every : Check_Interval := 1;
   end record;

   --  The machine's next phase and request after Evt in Current.
   procedure Advance
     (Current : in out Phase; Ctx : in out Context; Evt : Event_Kind);

   function Outcome_Of (P : Phase) return Outcome
   is (case P is
         when Certified  => Qp.Certified,
         when Infeasible => Qp.Infeasible,
         when Unbounded  => Qp.Unbounded,
         when Not_Convex => Qp.Not_Convex,
         when Stalled    => Qp.Stalled,
         when Diverged   => Qp.Diverged,
         when others     => Exhausted);

   --  Minimize over Pr from St, a cold or a warm start; Work holds the
   --  factor.  St holds the last iterate whatever the outcome.
   procedure Solve
     (Pr     : Problem;
      S      : Settings;
      Work   : in out Workspace;
      St     : in out State;
      Result : out Outcome)
   with
     Pre  => Fits_Work (Pr, Work) and then Fits_State (Pr, St),
     Post =>
       (if Result = Qp.Certified then Certificate.Certified (Pr, St, S.Tol));

end Abacus.Qp.Engine;
