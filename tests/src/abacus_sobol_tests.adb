with Interfaces; use Interfaces;

with AUnit.Assertions; use AUnit.Assertions;

with Abacus.Sobol; use Abacus.Sobol;

with Abacus_Sobol_Fixtures;

package body Abacus_Sobol_Tests is

   --  Eighths of the unit interval, as coordinates over 2**32.
   Eighth : constant := 2**29;

   type Eighths is array (1 .. 8) of Unsigned_32;

   --  The first eight points in three dimensions, as Joe and Kuo's
   --  program prints them: each coordinate in eighths.
   Published : constant array (1 .. 3) of Eighths :=
     [[0, 4, 6, 2, 3, 7, 5, 1],
      [0, 4, 2, 6, 3, 7, 1, 5],
      [0, 4, 2, 6, 5, 1, 7, 3]];

   procedure Test_First_Points (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      S  : Sequence := Unscrambled (3);
      X  : Point (1 .. 3);
      Ok : Boolean;
   begin
      for I in 1 .. 8 loop
         Next (S, X, Ok);
         Assert (Ok, "drawn");
         for J in 1 .. 3 loop
            Assert
              (X (J) = Published (J) (I) * Eighth,
               "point" & I'Image & ", coordinate" & J'Image);
         end loop;
      end loop;
   end Test_First_Points;

   --  The first 64 points in 64 dimensions equal scipy's, digit for
   --  digit: the direction numbers of every dimension are Joe and Kuo's.
   procedure Test_Against_Scipy (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      use Abacus_Sobol_Fixtures;
      Want : constant Plain_Table := Plain;
      S    : Sequence := Unscrambled (Plain_Dimensions);
      X    : Point (1 .. Plain_Dimensions);
      Ok   : Boolean;
   begin
      for I in Want'Range (1) loop
         Next (S, X, Ok);
         for J in Want'Range (2) loop
            Assert
              (X (J) = Want (I, J),
               "point" & I'Image & ", coordinate" & J'Image);
         end loop;
      end loop;
   end Test_Against_Scipy;

   --  Skipping to a far index gives the point there: every digit of every
   --  dimension's direction numbers is read on the way to the last.
   procedure Test_Skip_Far (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use Abacus_Sobol_Fixtures;
      X  : Point (1 .. Plain_Dimensions);
      Ok : Boolean;
   begin
      for P of Far loop
         declare
            S : Sequence := Unscrambled (Plain_Dimensions);
         begin
            Skip (S, P.Index, Ok);
            Assert (Ok and then Drawn (S) = P.Index, "skipped");
            Next (S, X, Ok);
            Assert (Ok and then X = P.X, "the point at" & P.Index'Image);
         end;
      end loop;
   end Test_Skip_Far;

   --  A skip in steps lands where one skip does, and where drawing does;
   --  a skip past the last point is refused and leaves the sequence; at
   --  the end, Next refuses.
   procedure Test_Skip (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Drawn_S, Skipped, Stepped : Sequence := Unscrambled (5);
      X, Y, Z                   : Point (1 .. 5);
      Ok                        : Boolean;
   begin
      for I in 1 .. 37 loop
         Next (Drawn_S, X, Ok);
      end loop;
      Skip (Skipped, 37, Ok);
      Skip (Stepped, 30, Ok);
      Skip (Stepped, 0, Ok);
      Skip (Stepped, 7, Ok);
      Next (Drawn_S, X, Ok);
      Next (Skipped, Y, Ok);
      Next (Stepped, Z, Ok);
      Assert (X = Y and then Y = Z, "one point");
      Skip (Skipped, Period, Ok);
      Assert (not Ok and then Drawn (Skipped) = 38, "past the end, refused");
      Skip (Skipped, Period - 38, Ok);
      Assert (Ok and then Drawn (Skipped) = Period, "to the end");
      Next (Skipped, Y, Ok);
      Assert (not Ok and then Y = [0, 0, 0, 0, 0], "none left");
   end Test_Skip;

   overriding
   procedure Register_Tests (T : in out Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T, Test_First_Points'Access, "The first points, as published");
      Register_Routine
        (T,
         Test_Against_Scipy'Access,
         "64 points in 64 dimensions, as scipy's");
      Register_Routine (T, Test_Skip_Far'Access, "Skipped to far indices");
      Register_Routine (T, Test_Skip'Access, "Skipping");
   end Register_Tests;

   overriding
   function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("Abacus.Sobol");
   end Name;

end Abacus_Sobol_Tests;
