with Spike_Grid_Tests;
with Spike_Admm_Tests;
with Spike_Deltas_Tests;
with Spike_Estimate_Tests;
with Spike_Kernels_Tests;
with Spike_Linear_Tests;

package body Spike_Suite is

   use AUnit.Test_Suites;

   Result  : aliased Test_Suite;
   Grid    : aliased Spike_Grid_Tests.Test;
   Kernels : aliased Spike_Kernels_Tests.Test;
   Linear  : aliased Spike_Linear_Tests.Test;
   Deltas  : aliased Spike_Deltas_Tests.Test;
   Est     : aliased Spike_Estimate_Tests.Test;
   Admm    : aliased Spike_Admm_Tests.Test;

   function Suite return Access_Test_Suite is
   begin
      Add_Test (Result'Access, Grid'Access);
      Add_Test (Result'Access, Kernels'Access);
      Add_Test (Result'Access, Linear'Access);
      Add_Test (Result'Access, Deltas'Access);
      Add_Test (Result'Access, Est'Access);
      Add_Test (Result'Access, Admm'Access);
      return Result'Access;
   end Suite;

end Spike_Suite;
