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

end Spike_Proof;
