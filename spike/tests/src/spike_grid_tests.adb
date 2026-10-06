with AUnit.Assertions; use AUnit.Assertions;
with Spike;            use Spike;
with Spike.Grid;

package body Spike_Grid_Tests is

   package G40 is new Spike.Grid (40);

   One : constant Wide := G40.One;

   --  A product of two halves is a quarter, and a half LSB rounds away
   --  from zero on both sides.
   procedure Test_Round_Half_Away (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
   begin
      Assert (G40.Round (One / 2 * (One / 2)) = One / 4, "half times half");
      Assert (G40.Round (One / 2) = 1, "half an LSB rounds up");
      Assert (G40.Round (-One / 2) = -1, "minus half an LSB rounds down");
      Assert (G40.Round (One / 2 - 1) = 0, "under half an LSB is zero");
   end Test_Round_Half_Away;

   overriding
   procedure Register_Tests (T : in out Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine (T, Test_Round_Half_Away'Access, "Round half away");
   end Register_Tests;

   overriding
   function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("Spike.Grid");
   end Name;

end Spike_Grid_Tests;
