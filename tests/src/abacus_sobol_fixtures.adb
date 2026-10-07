with Interfaces;

with Ada.Text_IO; use Ada.Text_IO;

package body Abacus_Sobol_Fixtures is

   package Coordinate_IO is new Ada.Text_IO.Modular_IO (Coordinate);
   package Raw_IO is new Ada.Text_IO.Integer_IO (Raw);

   Path : constant String := "tests/data/sobol.txt";

   --  The file opened past its first Lines lines.
   procedure Open_After (F : in out File_Type; Lines : Natural) is
   begin
      Open (F, In_File, Path);
      for L in 1 .. Lines loop
         Skip_Line (F);
      end loop;
   end Open_After;

   function Plain return Plain_Table is
      F      : File_Type;
      Result : Plain_Table;
   begin
      Open_After (F, 1);
      for I in Result'Range (1) loop
         for J in Result'Range (2) loop
            Coordinate_IO.Get (F, Result (I, J));
         end loop;
      end loop;
      Close (F);
      return Result;
   end Plain;

   function Scrambled return Scrambled_Table is
      F      : File_Type;
      Result : Scrambled_Table;
   begin
      Open_After (F, Plain_Points + 2);
      for I in Result'Range (1) loop
         for J in Result'Range (2) loop
            Coordinate_IO.Get (F, Result (I, J));
         end loop;
      end loop;
      Close (F);
      return Result;
   end Scrambled;

   function Measured return Discrepancies is
      F      : File_Type;
      Result : Discrepancies;
   begin
      Open_After (F, Plain_Points + Scrambled_Points + 3);
      Raw_IO.Get (F, Result.Ours);
      Raw_IO.Get (F, Result.Their_Mean);
      Raw_IO.Get (F, Result.Their_Largest);
      Raw_IO.Get (F, Result.Uniform_Mean);
      Close (F);
      return Result;
   end Measured;

   function Far return Far_Table is
      package Count_IO is new Ada.Text_IO.Modular_IO (Interfaces.Unsigned_64);
      F      : File_Type;
      Result : Far_Table;
      Index  : Interfaces.Unsigned_64;
   begin
      Open_After (F, Plain_Points + Scrambled_Points + 6);
      for P of Result loop
         Count_IO.Get (F, Index);
         P.Index := Index;
         for J in P.X'Range loop
            Coordinate_IO.Get (F, P.X (J));
         end loop;
      end loop;
      Close (F);
      return Result;
   end Far;

end Abacus_Sobol_Fixtures;
