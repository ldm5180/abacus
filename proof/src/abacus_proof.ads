with Abacus;

--  gnatprove analyses a unit only when it is in the closure of the
--  project's sources.  This package withs every Abacus unit so one
--  `gnatprove -P proof/proof.gpr` run covers the whole library, and
--  instantiates each generic, since gnatprove reasons about a generic
--  only through a concrete instance.  Keep this list complete.

package Abacus_Proof
  with SPARK_Mode
is

end Abacus_Proof;
