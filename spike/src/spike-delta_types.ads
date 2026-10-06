--  Representation (a): Ada fixed-point types with a binary Small, one
--  value type and one 128-bit accumulator per grid.  A value spans the
--  same 2**57 raw units as Spike.Val; the accumulator's Small is the
--  square of the value's, so a product converts to it exactly, and its
--  range is one and a half times the largest dot product.

package Spike.Delta_Types
  with SPARK_Mode, Pure
is

   type Fix_32 is delta 2.0**(-32) range -2.0**25 .. 2.0**25
   with Small => 2.0**(-32), Size => 64;
   type Acc_32 is
     delta 2.0**(-64) range -(2.0**62 + 2.0**61) .. 2.0**62 + 2.0**61
   with Small => 2.0**(-64), Size => 128;

   type Fix_40 is delta 2.0**(-40) range -2.0**17 .. 2.0**17
   with Small => 2.0**(-40), Size => 64;
   type Acc_40 is
     delta 2.0**(-80) range -(2.0**46 + 2.0**45) .. 2.0**46 + 2.0**45
   with Small => 2.0**(-80), Size => 128;

   type Fix_48 is delta 2.0**(-48) range -2.0**9 .. 2.0**9
   with Small => 2.0**(-48), Size => 64;
   type Acc_48 is
     delta 2.0**(-96) range -(2.0**30 + 2.0**29) .. 2.0**30 + 2.0**29
   with Small => 2.0**(-96), Size => 128;

end Spike.Delta_Types;
