with Ada.Text_IO; use Ada.Text_IO;

package body Fixtures is

   package Raw_IO is new Ada.Text_IO.Integer_IO (Raw);

   function Path (Stem : String; Frac : Natural) return String
   is ("tests/data/"
       & Stem
       & "_f"
       & Frac'Image (2 .. Frac'Image'Last)
       & ".txt");

   --  Rows x Cols integers after a header line, in file order.
   function Read (Name : String; Rows, Cols : Positive) return Matrix is
      F      : File_Type;
      Result : Matrix (1 .. Rows, 1 .. Cols);
      V      : Raw;
   begin
      Open (F, In_File, Name);
      Skip_Line (F);
      for I in 1 .. Rows loop
         for J in 1 .. Cols loop
            Raw_IO.Get (F, V);
            Result (I, J) := V;
         end loop;
      end loop;
      Close (F);
      return Result;
   end Read;

   function Returns (Frac : Natural) return Matrix is
      By_Day : constant Matrix := Read (Path ("returns", Frac), Days, Assets);
      Result : Matrix (1 .. Assets, 1 .. Days);
   begin
      for I in Result'Range (1) loop
         for T in Result'Range (2) loop
            Result (I, T) := By_Day (T, I);
         end loop;
      end loop;
      return Result;
   end Returns;

   function Weights (Frac : Natural) return Vector is
      W      : constant Matrix := Read (Path ("weights", Frac), 1, Assets);
      Result : Vector (1 .. Assets);
   begin
      for I in Result'Range loop
         Result (I) := W (1, I);
      end loop;
      return Result;
   end Weights;

   function Moments (Frac : Natural) return Matrix
   is (Read (Path ("moments", Frac), 4, Assets));

end Fixtures;
