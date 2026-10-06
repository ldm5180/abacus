with AUnit.Assertions; use AUnit.Assertions;

with Abacus; use Abacus;
with Abacus.Quantities;

package body Abacus_Quantities_Tests is

   --  A quantity between zero and one, as a consumer would declare one.
   package Shares is new Abacus.Quantities (First => 0, Last => One);
   use Shares;

   Quarter : constant Quantity := To_Quantity (One / 4);
   Half    : constant Quantity := To_Quantity (One / 2);

   --  Sums and differences stay quantities of the same kind.
   procedure Test_Sum (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Assert (Units (Quarter + Quarter) = One / 2, "a quarter twice");
      Assert (Half - Quarter = Quarter, "a half less a quarter");
      Assert (Units (Initial) = 0, "a quantity starts at zero");
   end Test_Sum;

   --  Quantities compare as their values do.
   procedure Test_Order (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Assert (Quarter < Half and then Quarter <= Half, "less");
      Assert (Half > Quarter and then Half >= Quarter, "greater");
      Assert (Half <= Half and then Half >= Half, "equal");
      Assert (not (Half < Half) and then not (Half > Half), "not strictly");
   end Test_Order;

   --  A quantity times a value, rounded once; and whether a raw result
   --  is one of this kind's values.
   procedure Test_Scaled (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Assert (Scaled (Half, One / 2) = Quarter, "half a half");
      Assert (Holds (Wide (One)), "one is a share");
      Assert (not Holds (Wide (One) + 1), "past one is not");
      Assert (not Holds (-1), "below zero is not");
   end Test_Scaled;

   overriding
   procedure Register_Tests (T : in out Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine (T, Test_Sum'Access, "Sums of a kind");
      Register_Routine (T, Test_Order'Access, "Comparison");
      Register_Routine (T, Test_Scaled'Access, "Scaling, and the range");
   end Register_Tests;

   overriding
   function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("Abacus.Quantities");
   end Name;

end Abacus_Quantities_Tests;
