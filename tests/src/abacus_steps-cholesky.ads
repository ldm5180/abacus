--  The Cholesky factorization (cholesky.feature): a matrix given,
--  factored or refused, and its factor used to solve.  A region of the
--  registry: Offer takes these steps, Reset starts a scenario, Phase
--  names its state.

package Abacus_Steps.Cholesky is

   procedure Offer
     (Ctx : in out Step_Context; Evt : Step_Kind; Handled : out Boolean);

   procedure Reset;

   function Phase return String;

end Abacus_Steps.Cholesky;
