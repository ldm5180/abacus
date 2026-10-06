with Spike.Grid;

--  The instances gnatprove analyses the spike's generics through: one per
--  grid the spike measures.

package Spike_Proof
  with SPARK_Mode
is

   package Grid_32 is new Spike.Grid (32);
   package Grid_40 is new Spike.Grid (40);
   package Grid_48 is new Spike.Grid (48);

end Spike_Proof;
