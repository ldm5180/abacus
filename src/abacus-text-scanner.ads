--  The lexer behind Abacus.Text.Parse, an sml state machine: one event
--  per character, walking sign, whole digits, point, fraction digits and
--  exponent.  It only collects the digits and where the point and the
--  exponent put them; Parse turns them into a value.

private package Abacus.Text.Scanner
  with SPARK_Mode
is

   subtype Digit is Natural range 0 .. 9;

   type Digit_Array is array (1 .. Max_Text) of Digit;

   --  The largest exponent kept; a larger one reads as this, which
   --  already puts any nonzero number out of range or below the grid.
   Max_Exponent : constant := 9_999;

   subtype Digit_Count is Natural range 0 .. Max_Text;

   --  A number as written: its sign, its digits in order, how many of
   --  them stand before the point, and its exponent.
   type Number is record
      Negative     : Boolean := False;
      Figures      : Digit_Array := [others => 0];
      Count        : Digit_Count := 0;
      Whole        : Digit_Count := 0;
      Exp_Negative : Boolean := False;
      Exponent     : Natural range 0 .. Max_Exponent := 0;
   end record;

   --  A scan: the number when Ok, else why not and where.
   type Scan_Result is record
      Ok       : Boolean := False;
      Number   : Scanner.Number;
      Error    : Error_Kind := Empty;
      Position : Natural := 0;
   end record;

   function Scan (Text : String) return Scan_Result
   with
     Pre  => Text'Length in 1 .. Max_Text,
     Post =>
       (if Scan'Result.Ok
        then
          Scan'Result.Error = None
          and then Scan'Result.Number.Whole <= Scan'Result.Number.Count
        else Scan'Result.Error in Unexpected | Incomplete);

end Abacus.Text.Scanner;
