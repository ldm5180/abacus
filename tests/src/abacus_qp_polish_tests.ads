with AUnit.Test_Cases;

--  Abacus.Qp.Polish: the bounds an iterate holds, the problem solved
--  with them held, their correction, and the polish as a whole.

package Abacus_Qp_Polish_Tests is

   type Test is new AUnit.Test_Cases.Test_Case with null record;

   overriding
   procedure Register_Tests (T : in out Test);

   overriding
   function Name (T : Test) return AUnit.Message_String;

end Abacus_Qp_Polish_Tests;
