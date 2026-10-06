with AUnit.Test_Cases;

--  Abacus.Sorting: a proved stable sort, ranks and quantiles.

package Abacus_Sorting_Tests is

   type Test is new AUnit.Test_Cases.Test_Case with null record;

   overriding
   procedure Register_Tests (T : in out Test);

   overriding
   function Name (T : Test) return AUnit.Message_String;

end Abacus_Sorting_Tests;
