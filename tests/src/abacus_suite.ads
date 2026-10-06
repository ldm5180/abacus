with AUnit.Test_Suites;

--  Every unit's tests, in the order the units build on each other.

package Abacus_Suite is

   function Suite return AUnit.Test_Suites.Access_Test_Suite;

end Abacus_Suite;
