with Abacus_Tests;

package body Abacus_Suite is

   use AUnit.Test_Suites;

   Result : aliased Test_Suite;
   Root   : aliased Abacus_Tests.Test;

   function Suite return Access_Test_Suite is
   begin
      Add_Test (Result'Access, Root'Access);
      return Result'Access;
   end Suite;

end Abacus_Suite;
