--  Elementary functions (elementary.feature): a function taken of a
--  number or of the last result, and the result checked.  A region of the
--  registry: Offer takes these steps, Reset starts a scenario, Phase
--  names its state.

package Abacus_Steps.Elementary is

   procedure Offer
     (Ctx : in out Step_Context; Evt : Step_Kind; Handled : out Boolean);

   procedure Reset;

   function Phase return String;

end Abacus_Steps.Elementary;
