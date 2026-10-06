with Ada.Text_IO; use Ada.Text_IO;

package body Abacus_Qp_Fixtures is

   package Raw_IO is new Ada.Text_IO.Integer_IO (Raw);

   function Path (Name : String) return String
   is ("tests/data/qp_" & Name & ".txt");

   procedure Get_Vector (F : File_Type; V : out Vector) is
   begin
      for I in V'Range loop
         Raw_IO.Get (F, V (I));
      end loop;
   end Get_Vector;

   procedure Get_Matrix (F : File_Type; M : out Matrix) is
   begin
      for I in M'Range (1) loop
         for J in M'Range (2) loop
            Raw_IO.Get (F, M (I, J));
         end loop;
      end loop;
   end Get_Matrix;

   --  The sizes on the file's second line, the file left after them.
   procedure Open_Sized (F : in out File_Type; Name : String; N, K : out Raw)
   is
   begin
      Open (F, In_File, Path (Name));
      Skip_Line (F);
      Raw_IO.Get (F, N);
      Raw_IO.Get (F, K);
   end Open_Sized;

   procedure Get_Problem (F : File_Type; Pr : out Problem) is
   begin
      Get_Matrix (F, Pr.P);
      Get_Vector (F, Pr.Q);
      Get_Vector (F, Pr.Lo);
      Get_Vector (F, Pr.Hi);
      Get_Matrix (F, Pr.E);
      Get_Vector (F, Pr.Row_Lo);
      Get_Vector (F, Pr.Row_Hi);
   end Get_Problem;

   function Load (Name : String) return Problem is
      F    : File_Type;
      N, K : Raw;
   begin
      Open_Sized (F, Name, N, K);
      return Pr : Problem (Index (N), Abacus.Count (K)) do
         Get_Problem (F, Pr);
         Close (F);
      end return;
   end Load;

   function Has_Answer (Name : String) return Boolean is
      F      : File_Type;
      Line   : String (1 .. 5);
      Last   : Natural := 0;
      Result : Boolean := True;
   begin
      Open (F, In_File, Path (Name));
      while not End_Of_File (F) loop
         Get_Line (F, Line, Last);
         if Last < Line'Last then
            Result := Line (1 .. Last) /= "none";
         else
            Result := True;
            Skip_Line (F);
         end if;
      end loop;
      Close (F);
      return Result;
   end Has_Answer;

   function Answer (Name : String) return Vector is
      F    : File_Type;
      N, K : Raw;
   begin
      Open_Sized (F, Name, N, K);
      declare
         Pr : Problem (Index (N), Abacus.Count (K));
         X  : Vector (1 .. Index (N));
      begin
         Get_Problem (F, Pr);
         Get_Vector (F, X);
         Close (F);
         return X;
      end;
   end Answer;

end Abacus_Qp_Fixtures;
