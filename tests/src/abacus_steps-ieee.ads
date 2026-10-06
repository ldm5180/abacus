--  IEEE-754 bit patterns (ieee.feature): a pattern read, and the value
--  or the refusal it read as checked.  A region of the
--  registry: Offer takes these steps, Reset starts a scenario, Phase
--  names its state.

package Abacus_Steps.Ieee is

   procedure Offer
     (Ctx : in out Step_Context; Evt : Step_Kind; Handled : out Boolean);

   procedure Reset;

   function Phase return String;

end Abacus_Steps.Ieee;
