--  Decimal text (text.feature): a text read, and the value or the
--  refusal it read as checked, then written back.  A region of the
--  registry: Offer takes these steps, Reset starts a scenario, Phase
--  names its state.

package Abacus_Steps.Text is

   procedure Offer
     (Ctx : in out Step_Context; Evt : Step_Kind; Handled : out Boolean);

   procedure Reset;

   function Phase return String;

end Abacus_Steps.Text;
