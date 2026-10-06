with AUnit.Test_Cases;

--  Abacus.Vectors: dot products, sums, norms, axpy and scaling.

package Abacus_Vectors_Tests is

   type Test is new AUnit.Test_Cases.Test_Case with null record;

   overriding
   procedure Register_Tests (T : in out Test);

   overriding
   function Name (T : Test) return AUnit.Message_String;

end Abacus_Vectors_Tests;
