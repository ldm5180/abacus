with Abacus_Arith_Tests;
with Abacus_Elementary_Tests;
with Abacus_Ieee_Tests;
with Abacus_Quantities_Tests;
with Abacus_Sorting_Tests;
with Abacus_Stats_Rolling_Tests;
with Abacus_Stats_Tests;
with Abacus_Tests;
with Abacus_Text_Tests;
with Abacus_Vectors_Tests;

package body Abacus_Suite is

   use AUnit.Test_Suites;

   Result : aliased Test_Suite;
   Root   : aliased Abacus_Tests.Test;
   Arith  : aliased Abacus_Arith_Tests.Test;
   Quant  : aliased Abacus_Quantities_Tests.Test;
   Text   : aliased Abacus_Text_Tests.Test;
   Ieee   : aliased Abacus_Ieee_Tests.Test;
   Elem   : aliased Abacus_Elementary_Tests.Test;
   Vect   : aliased Abacus_Vectors_Tests.Test;
   Sort   : aliased Abacus_Sorting_Tests.Test;
   Stats  : aliased Abacus_Stats_Tests.Test;
   Roll   : aliased Abacus_Stats_Rolling_Tests.Test;

   function Suite return Access_Test_Suite is
   begin
      Add_Test (Result'Access, Root'Access);
      Add_Test (Result'Access, Arith'Access);
      Add_Test (Result'Access, Quant'Access);
      Add_Test (Result'Access, Text'Access);
      Add_Test (Result'Access, Ieee'Access);
      Add_Test (Result'Access, Elem'Access);
      Add_Test (Result'Access, Vect'Access);
      Add_Test (Result'Access, Sort'Access);
      Add_Test (Result'Access, Stats'Access);
      Add_Test (Result'Access, Roll'Access);
      return Result'Access;
   end Suite;

end Abacus_Suite;
