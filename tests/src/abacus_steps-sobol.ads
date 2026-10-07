--  Scrambled Sobol sequences (sobol.feature): a sequence named, points
--  or a block drawn from it, and the points checked.  A region of the
--  registry: Offer takes these steps.  Its machine's state is held in
--  the scenario (World.Sobol.Stage), so Reset has nothing to clear and
--  Phase names where it is kept.

package Abacus_Steps.Sobol is

   procedure Offer
     (Ctx : in out Step_Context; Evt : Step_Kind; Handled : out Boolean);

   procedure Reset;

   function Phase return String;

end Abacus_Steps.Sobol;
