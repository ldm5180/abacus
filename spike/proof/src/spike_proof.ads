with Spike.Delta_Types; use Spike.Delta_Types;
with Spike.Deltas;
with Spike.Grid;
with Spike.Linear;

--  The instances gnatprove analyses the spike's generics through: one per
--  grid the spike measures.

package Spike_Proof
  with SPARK_Mode
is

   package Grid_32 is new Spike.Grid (32);
   package Grid_40 is new Spike.Grid (40);
   package Grid_48 is new Spike.Grid (48);

   package Linear_32 is new Spike.Linear (32);
   package Linear_40 is new Spike.Linear (40);
   package Linear_48 is new Spike.Linear (48);

   package Deltas_32 is new Spike.Deltas (Fix_32, Acc_32);
   package Deltas_40 is new Spike.Deltas (Fix_40, Acc_40);
   package Deltas_48 is new Spike.Deltas (Fix_48, Acc_48);

end Spike_Proof;
