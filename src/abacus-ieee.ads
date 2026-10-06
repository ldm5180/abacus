with Interfaces;

--  IEEE-754 binary64 and binary32 bit patterns to values.  The sign,
--  exponent and fraction are taken apart as integers and the number is
--  rounded to the grid, ties away from zero; nothing is reinterpreted
--  as a float.

package Abacus.Ieee
  with SPARK_Mode
is

   --  How a pattern read: as a value, or refused as not-a-number, as an
   --  infinity, or as a number past the values.  Zero and the
   --  subnormals read as values.
   type Outcome is (Ok, Not_A_Number, Infinite, Out_Of_Range);

   --  A read: the value when the outcome is Ok, zero otherwise.
   type Read is record
      Outcome : Ieee.Outcome := Ok;
      Value   : Val := 0;
   end record;

   function From_Binary64 (Bits : Interfaces.Unsigned_64) return Read
   with
     Post =>
       From_Binary64'Result.Outcome = Ok
       or else From_Binary64'Result.Value = 0;

   function From_Binary32 (Bits : Interfaces.Unsigned_32) return Read
   with
     Post =>
       From_Binary32'Result.Outcome = Ok
       or else From_Binary32'Result.Value = 0;

end Abacus.Ieee;
