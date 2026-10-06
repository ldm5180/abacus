--  Decimal text to values and back.  A number reads as the value on the
--  grid nearest to it, exactly: its digits are converted by integer
--  arithmetic, never through a float, and a tie rounds away from zero.
--  A value writes back as the shortest text that reads as it again.

package Abacus.Text
  with SPARK_Mode
is

   --  The longest text Parse reads.
   Max_Text : constant := 64;

   --  Why a text is not a value: it is empty, it holds a character
   --  that cannot stand where it does, it stops before the number is
   --  complete ("-", "1e", "."), it is longer than Max_Text, or the
   --  number lies past the values.
   type Error_Kind is
     (None, Empty, Unexpected, Incomplete, Too_Long, Out_Of_Range);

   --  A read: the value when Ok, else why not and, for an unexpected
   --  character, its position in the text.
   type Read is record
      Ok       : Boolean := False;
      Value    : Val := 0;
      Error    : Error_Kind := Empty;
      Position : Natural := 0;
   end record;

   --  An optional sign, digits with an optional point among them, and
   --  an optional exponent ("e" or "E", an optional sign, digits).
   function Parse (Text : String) return Read
   with
     Post =>
       (if Parse'Result.Ok
        then Parse'Result.Error = None
        else Parse'Result.Value = 0 and then Parse'Result.Error /= None);

   --  The most decimal places Image writes.  Thirteen always suffice to
   --  read back as the same value; more add digits, not accuracy.
   Max_Places : constant := 20;

   subtype Place_Count is Natural range 0 .. Max_Places;

   --  The longest text Image returns: a sign, the whole part, the point
   --  and Max_Places places.
   Max_Image : constant := 1 + 6 + 1 + Max_Places;

   --  V in decimal: the shortest text of at most Places places that
   --  reads as V, or V rounded to Places places when none does.
   function Image (V : Val; Places : Place_Count := Max_Places) return String
   with
     Post => Image'Result'First = 1 and then Image'Result'Length <= Max_Image;

end Abacus.Text;
