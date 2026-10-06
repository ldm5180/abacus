with AUnit.Test_Cases;

--  Abacus.Ieee: binary64 and binary32 bit patterns to values.

package Abacus_Ieee_Tests is

   type Test is new AUnit.Test_Cases.Test_Case with null record;

   overriding
   procedure Register_Tests (T : in out Test);

   overriding
   function Name (T : Test) return AUnit.Message_String;

end Abacus_Ieee_Tests;
