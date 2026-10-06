with Abacus;
with Abacus.Arith;
with Abacus.Elementary;
with Abacus.Ieee;
with Abacus.Quantities;
with Abacus.Text;
with Abacus.Vectors;

--  gnatprove analyses a unit only when it is in the closure of the
--  project's sources.  This package withs every Abacus unit so one
--  `gnatprove -P proof/proof.gpr` run covers the whole library, and
--  instantiates each generic, since gnatprove reasons about a generic
--  only through a concrete instance.  Keep this list complete.

package Abacus_Proof
  with SPARK_Mode
is

   --  A quantity over every value, and one over the unit interval.
   package All_Values is new Abacus.Quantities;
   package Shares is new Abacus.Quantities (0, Abacus.One);

end Abacus_Proof;
