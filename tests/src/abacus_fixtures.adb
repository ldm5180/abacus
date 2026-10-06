with Ada.Strings.Fixed;
with Ada.Text_IO;

package body Abacus_Fixtures is

   --  The words of Text, split on blanks.
   procedure Next_Word
     (Text : String; From : in out Positive; First, Last : out Natural) is
   begin
      while From <= Text'Last and then Text (From) = ' ' loop
         From := From + 1;
      end loop;
      First := From;
      while From <= Text'Last and then Text (From) /= ' ' loop
         From := From + 1;
      end loop;
      Last := From - 1;
   end Next_Word;

   function Parse_Line (Text : String) return Line is
      Result      : Line;
      From        : Positive := Text'First;
      First, Last : Natural;
   begin
      Next_Word (Text, From, First, Last);
      Ada.Strings.Fixed.Move
        (Text (First .. Last), Result.Tag, Drop => Ada.Strings.Right);
      loop
         Next_Word (Text, From, First, Last);
         exit when Last < First or else Result.Count = Max_Fields;
         Result.Count := Result.Count + 1;
         Result.Values (Result.Count) := Raw'Value (Text (First .. Last));
      end loop;
      return Result;
   end Parse_Line;

   function Lines (Name : String) return Line_Vectors.Vector is
      File   : Ada.Text_IO.File_Type;
      Result : Line_Vectors.Vector;
   begin
      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, "tests/data/" & Name);
      Ada.Text_IO.Skip_Line (File);
      while not Ada.Text_IO.End_Of_File (File) loop
         Result.Append (Parse_Line (Ada.Text_IO.Get_Line (File)));
      end loop;
      Ada.Text_IO.Close (File);
      return Result;
   end Lines;

   function Is_Tagged (L : Line; Tag : String) return Boolean
   is (Ada.Strings.Fixed.Trim (L.Tag, Ada.Strings.Right) = Tag);

end Abacus_Fixtures;
