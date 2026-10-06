with Interfaces; use Interfaces;

with AUnit.Assertions; use AUnit.Assertions;

with Abacus;      use Abacus;
with Abacus.Ieee; use Abacus.Ieee;

package body Abacus_Ieee_Tests is

   procedure Reads_64 (Bits : Unsigned_64; Want : Read; What : String) is
      Got : constant Read := From_Binary64 (Bits);
   begin
      Assert
        (Got = Want,
         What
         & " reads as"
         & Got.Value'Image
         & " "
         & Got.Outcome'Image
         & ", want"
         & Want.Value'Image
         & " "
         & Want.Outcome'Image);
   end Reads_64;

   procedure Reads_32 (Bits : Unsigned_32; Want : Read; What : String) is
      Got : constant Read := From_Binary32 (Bits);
   begin
      Assert
        (Got = Want,
         What & " reads as" & Got.Value'Image & " " & Got.Outcome'Image);
   end Reads_32;

   --  Minus one hundred and twenty, in units.
   Minus_120 : constant := -120 * One;

   --  The units nearest a tenth: 2**40 / 10 is 109951162777.6.
   Tenth : constant := 109_951_162_778;

   --  Whole numbers, a fraction the grid cannot hold, and the largest
   --  value.
   procedure Test_Numbers (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Reads_64 (16#C05E_0000_0000_0000#, (Ok, Minus_120), "-120.0");
      Reads_64 (16#3FF0_0000_0000_0000#, (Ok, One), "1.0");
      Reads_64 (16#3FB9_9999_9999_999A#, (Ok, Tenth), "0.1");
      Reads_64 (16#BFB9_9999_9999_999A#, (Ok, -Tenth), "-0.1");
      Reads_64 (16#4100_0000_0000_0000#, (Ok, Val_Bound), "131072.0");
      Reads_64 (16#C100_0000_0000_0000#, (Ok, -Val_Bound), "-131072.0");
   end Test_Numbers;

   --  Zero either way, a subnormal, and numbers at and below half a unit.
   procedure Test_Small (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Reads_64 (0, (Ok, 0), "zero");
      Reads_64 (16#8000_0000_0000_0000#, (Ok, 0), "negative zero");
      Reads_64 (1, (Ok, 0), "the least subnormal");
      Reads_64 (16#000F_FFFF_FFFF_FFFF#, (Ok, 0), "the largest subnormal");
      Reads_64 (16#3D60_0000_0000_0000#, (Ok, 1), "half a unit, away");
      Reads_64 (16#BD60_0000_0000_0000#, (Ok, -1), "minus half a unit");
      Reads_64 (16#3D50_0000_0000_0000#, (Ok, 0), "a quarter unit");
      Reads_64 (16#3D68_0000_0000_0000#, (Ok, 1), "three quarters of a unit");
      Reads_64 (16#3D78_0000_0000_0000#, (Ok, 2), "one and a half units");
   end Test_Small;

   --  Not-a-number, the infinities, and numbers past the values.
   procedure Test_Refused (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Reads_64 (16#7FF8_0000_0000_0000#, (Not_A_Number, 0), "a quiet NaN");
      Reads_64 (16#7FF0_0000_0000_0001#, (Not_A_Number, 0), "a signaling NaN");
      Reads_64 (16#FFF8_0000_0000_0000#, (Not_A_Number, 0), "a negative NaN");
      Reads_64 (16#7FF0_0000_0000_0000#, (Infinite, 0), "infinity");
      Reads_64 (16#FFF0_0000_0000_0000#, (Infinite, 0), "minus infinity");
      Reads_64 (16#7E37_E43C_8800_759C#, (Out_Of_Range, 0), "1e300");
      Reads_64 (16#4100_0000_0000_0001#, (Out_Of_Range, 0), "past 131072");
      Reads_64 (16#C100_0000_0000_0001#, (Out_Of_Range, 0), "below -131072");
      Reads_64 (16#7FEF_FFFF_FFFF_FFFF#, (Out_Of_Range, 0), "the largest");
   end Test_Refused;

   --  binary32: the same rules on the narrower layout.
   procedure Test_Binary32 (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Tenth_32 : constant := 109_951_164_416;
   begin
      Reads_32 (16#3F00_0000#, (Ok, One / 2), "0.5");
      Reads_32 (16#C2F0_0000#, (Ok, Minus_120), "-120.0");
      Reads_32 (16#3DCC_CCCD#, (Ok, Tenth_32), "0.1 as binary32");
      Reads_32 (16#8000_0000#, (Ok, 0), "negative zero");
      Reads_32 (1, (Ok, 0), "a subnormal");
      Reads_32 (16#4800_0000#, (Ok, Val_Bound), "131072.0");
      Reads_32 (16#4800_0001#, (Out_Of_Range, 0), "past 131072");
      Reads_32 (16#7FC0_0000#, (Not_A_Number, 0), "NaN");
      Reads_32 (16#FF80_0000#, (Infinite, 0), "minus infinity");
   end Test_Binary32;

   overriding
   procedure Register_Tests (T : in out Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine (T, Test_Numbers'Access, "Numbers read as values");
      Register_Routine (T, Test_Small'Access, "Zero, subnormals, ties");
      Register_Routine (T, Test_Refused'Access, "Refused by name");
      Register_Routine (T, Test_Binary32'Access, "binary32");
   end Register_Tests;

   overriding
   function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("Abacus.Ieee");
   end Name;

end Abacus_Ieee_Tests;
