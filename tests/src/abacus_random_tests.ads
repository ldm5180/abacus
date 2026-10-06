with AUnit.Test_Cases;

--  Abacus.Random: a seeded 64-bit generator.

package Abacus_Random_Tests is

   type Test is new AUnit.Test_Cases.Test_Case with null record;

   overriding
   procedure Register_Tests (T : in out Test);

   overriding
   function Name (T : Test) return AUnit.Message_String;

end Abacus_Random_Tests;
