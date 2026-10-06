--  Statistics (stats.feature): data given, a statistic taken of them,
--  and the answer checked.  A region of the
--  registry: Offer takes these steps, Reset starts a scenario, Phase
--  names its state.

package Abacus_Steps.Stats is

   procedure Offer
     (Ctx : in out Step_Context; Evt : Step_Kind; Handled : out Boolean);

   procedure Reset;

   function Phase return String;

end Abacus_Steps.Stats;
