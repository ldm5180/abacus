with AUnit.Test_Cases;

--  Abacus.Qp.Held: the problem solved with a set of bounds held, for a
--  cost given; the held rows' square system solved and transposed; and
--  the first held row or free column that depends on those before it.

package Abacus_Qp_Held_Tests is

   type Test is new AUnit.Test_Cases.Test_Case with null record;

   overriding
   procedure Register_Tests (T : in out Test);

   overriding
   function Name (T : Test) return AUnit.Message_String;

end Abacus_Qp_Held_Tests;
