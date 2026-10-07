with Ada.Strings.Fixed;
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

   --  What a file's first two lines say: the sizes, and whether it holds
   --  the rows' kinds.
   type Header is record
      N, K  : Raw;
      Kinds : Boolean;
   end record;

   --  The file opened and its header read, the file left after it.
   procedure Open_Sized (F : in out File_Type; Name : String; H : out Header)
   is
   begin
      Open (F, In_File, Path (Name));
      H.Kinds := Ada.Strings.Fixed.Index (Get_Line (F), "kinds") > 0;
      Raw_IO.Get (F, H.N);
      Raw_IO.Get (F, H.K);
   end Open_Sized;

   --  The rows' kinds, written 0 (an interval), 1 (a cone's head) or 2
   --  (a cone's tail).
   procedure Get_Kinds (F : File_Type; Kind : out Row_Kinds) is
      Code : Raw;
   begin
      for R in Kind'Range loop
         Raw_IO.Get (F, Code);
         Kind (R) := Row_Kind'Val (Code);
      end loop;
   end Get_Kinds;

   procedure Get_Problem (F : File_Type; Kinds : Boolean; Pr : out Problem) is
   begin
      Get_Matrix (F, Pr.P);
      Get_Vector (F, Pr.Q);
      Get_Vector (F, Pr.Lo);
      Get_Vector (F, Pr.Hi);
      Get_Matrix (F, Pr.E);
      Get_Vector (F, Pr.Row_Lo);
      Get_Vector (F, Pr.Row_Hi);
      Pr.Kind := [others => Interval];
      if Kinds then
         Get_Kinds (F, Pr.Kind);
      end if;
   end Get_Problem;

   function Load (Name : String) return Problem is
      F : File_Type;
      H : Header;
   begin
      Open_Sized (F, Name, H);
      return Pr : Problem (Index (H.N), Abacus.Count (H.K)) do
         Get_Problem (F, H.Kinds, Pr);
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
      F : File_Type;
      H : Header;
   begin
      Open_Sized (F, Name, H);
      declare
         Pr : Problem (Index (H.N), Abacus.Count (H.K));
         X  : Vector (1 .. Index (H.N));
      begin
         Get_Problem (F, H.Kinds, Pr);
         Get_Vector (F, X);
         Close (F);
         return X;
      end;
   end Answer;

end Abacus_Qp_Fixtures;
