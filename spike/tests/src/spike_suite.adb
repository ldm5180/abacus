with Spike_Grid_Tests;

package body Spike_Suite is

   use AUnit.Test_Suites;

   Result : aliased Test_Suite;
   Grid   : aliased Spike_Grid_Tests.Test;

   function Suite return Access_Test_Suite is
   begin
      Add_Test (Result'Access, Grid'Access);
      return Result'Access;
   end Suite;

end Spike_Suite;
