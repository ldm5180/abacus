with AUnit.Test_Cases;

--  Abacus.Qp.Crossover: from the bounds an iterate holds to an optimal
--  vertex of a linear program, by pivots, certified.

package Abacus_Qp_Crossover_Tests is

   type Test is new AUnit.Test_Cases.Test_Case with null record;

   overriding
   procedure Register_Tests (T : in out Test);

   overriding
   function Name (T : Test) return AUnit.Message_String;

end Abacus_Qp_Crossover_Tests;
