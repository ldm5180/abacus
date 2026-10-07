with AUnit.Test_Cases;

--  Abacus.Qp.Cones: the second-order cone's norm, projection and
--  excess.

package Abacus_Qp_Cones_Tests is

   type Test is new AUnit.Test_Cases.Test_Case with null record;

   overriding
   procedure Register_Tests (T : in out Test);

   overriding
   function Name (T : Test) return AUnit.Message_String;

end Abacus_Qp_Cones_Tests;
