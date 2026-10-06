with Abacus_Arith_Tests;
with Abacus_Quantities_Tests;
with Abacus_Tests;

package body Abacus_Suite is

   use AUnit.Test_Suites;

   Result : aliased Test_Suite;
   Root   : aliased Abacus_Tests.Test;
   Arith  : aliased Abacus_Arith_Tests.Test;
   Quant  : aliased Abacus_Quantities_Tests.Test;

   function Suite return Access_Test_Suite is
   begin
      Add_Test (Result'Access, Root'Access);
      Add_Test (Result'Access, Arith'Access);
      Add_Test (Result'Access, Quant'Access);
      return Result'Access;
   end Suite;

end Abacus_Suite;
