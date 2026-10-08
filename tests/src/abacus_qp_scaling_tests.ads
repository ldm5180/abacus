with AUnit.Test_Cases;

--  Abacus.Qp.Scaling: the exponent of a value, and the step sizes an
--  equilibration of a problem gives its rows and variables.

package Abacus_Qp_Scaling_Tests is

   type Test is new AUnit.Test_Cases.Test_Case with null record;

   overriding
   procedure Register_Tests (T : in out Test);

   overriding
   function Name (T : Test) return AUnit.Message_String;

end Abacus_Qp_Scaling_Tests;
