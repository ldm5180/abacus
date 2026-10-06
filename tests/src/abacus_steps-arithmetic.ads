--  Arithmetic on the grid (arithmetic.feature): values given in units,
--  combined, and the result checked.  A region of the registry: Offer
--  takes these steps, Reset starts a scenario, Phase names its state.

package Abacus_Steps.Arithmetic is

   procedure Offer
     (Ctx : in out Step_Context; Evt : Step_Kind; Handled : out Boolean);

   procedure Reset;

   function Phase return String;

end Abacus_Steps.Arithmetic;
