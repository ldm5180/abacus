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
   end Register_Tests;

   overriding
   function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("Abacus.Sobol");
   end Name;

end Abacus_Sobol_Tests;
