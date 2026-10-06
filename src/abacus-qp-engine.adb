with Sml.Machines;
with Sml.Machines.Operators;

with Abacus.Qp.Admm;

package body Abacus.Qp.Engine
  with SPARK_Mode
is

   type Guard_Kind is (Always, Due, Capped);

   type Action_Kind is (Nothing, Ask_Step, Ask_Check, Ask_Certify, Ask_Stop);

   type Event (Kind : Event_Kind := E_Ready) is null record;

   function Kind_Of (E : Event) return Event_Kind
   is (E.Kind);

   function Is_Due (Ctx : Context) return Boolean
   is (Ctx.Iterations mod Ctx.Check_Every = 0);

   function Is_Capped (Ctx : Context) return Boolean
   is (Ctx.Iterations >= Ctx.Max_Iter);

   function Evaluate
     (G : Guard_Kind; Ctx : Context; Evt : Event) return Boolean
   is
      pragma Unreferenced (Evt);
   begin
      return
        (case G is
           when Always => True,
           when Due    => Is_Due (Ctx) or else Is_Capped (Ctx),
           when Capped => Is_Capped (Ctx));
   end Evaluate;

   procedure Execute (A : Action_Kind; Ctx : in out Context; Evt : Event) is
      pragma Unreferenced (Evt);
   begin
      Ctx.Request :=
        (case A is
           when Nothing     => Ctx.Request,
           when Ask_Step    => Step,
           when Ask_Check   => Check,
           when Ask_Certify => Certify,
           when Ask_Stop    => Stop);
   end Execute;

   package SM is new
     Sml.Machines
       (State       => Phase,
        Event_Kind  => Event_Kind,
        Event       => Event,
        Context     => Context,
        Guard_Kind  => Guard_Kind,
        Action_Kind => Action_Kind,
        Kind_Of     => Kind_Of,
        Evaluate    => Evaluate,
        Execute     => Execute);

   package Op is new SM.Operators (Always => Always, Nothing => Nothing);
   use SM, Op;

   Ready             : constant Ev := (Kind => E_Ready);
   Indefinite        : constant Ev := (Kind => E_Indefinite);
   Out_Of_Range      : constant Ev := (Kind => E_Out_Of_Range);
   Stepped           : constant Ev := (Kind => E_Stepped);
   Converged         : constant Ev := (Kind => E_Converged);
   Primal_Infeasible : constant Ev := (Kind => E_Primal_Infeasible);
   Dual_Infeasible   : constant Ev := (Kind => E_Dual_Infeasible);
   Held              : constant Ev := (Kind => E_Held);
   Moving            : constant Ev := (Kind => E_Moving);
   Passed            : constant Ev := (Kind => E_Passed);
   Not_Passed        : constant Ev := (Kind => E_Not_Passed);

   --  From + Event (Guard) / Action >= To.  A step is checked when the
   --  check is due or the cap is reached; converged residuals are then
   --  certified, and an answer that is not yet certified iterates on
   --  until the cap.
   --!format off
   Table : constant Transition_Table :=
     [Preparing  + Ready                      / Ask_Step    >= Iterating,
      Preparing  + Indefinite                 / Ask_Stop    >= Not_Convex,
      Preparing  + Out_Of_Range               / Ask_Stop    >= Diverged,
      Iterating  + Stepped           (Due)    / Ask_Check   >= Checking,
      Iterating  + Stepped                    / Ask_Step    >= Iterating,
      Iterating  + Out_Of_Range               / Ask_Stop    >= Diverged,
      Checking   + Converged                  / Ask_Certify >= Certifying,
      Checking   + Primal_Infeasible          / Ask_Stop    >= Infeasible,
      Checking   + Dual_Infeasible            / Ask_Stop    >= Unbounded,
      Checking   + Held                       / Ask_Stop    >= Stalled,
      Checking   + Moving            (Capped) / Ask_Stop    >= Exhausted,
      Checking   + Moving                     / Ask_Step    >= Iterating,
      Certifying + Passed                     / Ask_Stop    >= Certified,
      Certifying + Not_Passed        (Capped) / Ask_Stop    >= Exhausted,
      Certifying + Not_Passed                 / Ask_Step    >= Iterating];
   --!format on

   procedure Advance
     (Current : in out Phase; Ctx : in out Context; Evt : Event_Kind)
   is
      M       : Machine := Make (Table, Initial => Current);
      Handled : Boolean;
   begin
      Process_Event (M, Ctx, (Kind => Evt), Handled);
      Current := State_Of (M);
      if not Handled then
         Ctx.Request := Stop;
      end if;
   end Advance;

   ---------------------------------------------------------------------
   --  The runner: each request carried out, and what it found.
   ---------------------------------------------------------------------

   use type Admm.Prepare_Result;

   function Prepared (R : Admm.Prepare_Result) return Event_Kind
   is (case R is
         when Admm.Ready        => E_Ready,
         when Admm.Not_Convex   => E_Indefinite,
         when Admm.Out_Of_Range => E_Out_Of_Range);

   function Checked (V : Admm.Verdict) return Event_Kind
   is (case V is
         when Admm.Converged         => E_Converged,
         when Admm.Primal_Infeasible => E_Primal_Infeasible,
         when Admm.Dual_Infeasible   => E_Dual_Infeasible,
         when Admm.Held              => E_Held,
         when Admm.Moving            => E_Moving);

   --  The iterate, and the iterate at the last check.
   type Iterates
     (N : Index;
      K : Count)
   is record
      Now  : State (N, K);
      Last : State (N, K);
   end record;

   --  Ctx's request carried out, and what it found into Ctx.Found.
   procedure Run
     (Pr   : Problem;
      S    : Settings;
      Work : in out Workspace;
      It   : in out Iterates;
      Ctx  : in out Context)
   with Pre => Fits_Work (Pr, Work) and then It.N = Pr.N and then It.K = Pr.K
   is
      Ok      : Boolean;
      Setup   : Admm.Prepare_Result;
      Verdict : Admm.Verdict;
   begin
      case Ctx.Request is
         when Prepare     =>
            Admm.Prepare (Pr, S, Work, Setup);
            Ctx.Found := Prepared (Setup);

         when Step        =>
            Admm.Iterate (Pr, S, Work, It.Now, Ok);
            Ctx.Found := (if Ok then E_Stepped else E_Out_Of_Range);
            Ctx.Iterations := It.Now.Iterations;

         when Check       =>
            Admm.Check (Pr, S, It.Now, It.Last, Verdict);
            Ctx.Found := Checked (Verdict);

         when Certify     =>
            Ctx.Found :=
              (if Certificate.Certified (Pr, It.Now, S.Tol)
               then E_Passed
               else E_Not_Passed);

         when Engine.Stop =>
            Ctx.Found := E_Not_Passed;
      end case;
   end Run;

   procedure Solve
     (Pr     : Problem;
      S      : Settings;
      Work   : in out Workspace;
      St     : in out State;
      Result : out Outcome)
   is
      It      : Iterates (Pr.N, Pr.K) := (Pr.N, Pr.K, St, St);
      Current : Phase := Preparing;
      Ctx     : Context :=
        (Request     => Prepare,
         Found       => E_Ready,
         Iterations  => St.Iterations,
         Max_Iter    => S.Max_Iter,
         Check_Every => S.Check_Every);
   begin
      --  Each iteration takes at most a step, a check and a certificate.
      for Turn in 1 .. 3 * S.Max_Iter + 1 loop
         exit when Current in Final or else Ctx.Request = Stop;
         Run (Pr, S, Work, It, Ctx);
         Advance (Current, Ctx, Ctx.Found);
      end loop;
      St := It.Now;
      Result := Outcome_Of (Current);
      if Result = Qp.Certified
        and then not Certificate.Certified (Pr, St, S.Tol)
      then
         Result := Exhausted;
      end if;
   end Solve;

end Abacus.Qp.Engine;
