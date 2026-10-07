with Ada.Unchecked_Deallocation;

with Interfaces; use Interfaces;

with AUnit.Assertions; use AUnit.Assertions;

with Abacus;
use type Abacus.Raw;
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

   --  The scramble agrees with a second implementation of it, the
   --  fixture script's, point for point.
   procedure Test_Scrambled (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use Abacus_Sobol_Fixtures;
      Want : constant Scrambled_Table := Scrambled;
      S    : Sequence := Abacus.Sobol.Scrambled (Scrambled_Dimensions, Seed);
      X    : Point (1 .. Scrambled_Dimensions);
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
   end Test_Scrambled;

   --  One seed gives one stream; two seeds give two, and neither is the
   --  unscrambled one.
   procedure Test_Seeds (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Draws      : constant := 1_000;
      A, B       : Sequence := Abacus.Sobol.Scrambled (6, 42);
      C          : Sequence := Abacus.Sobol.Scrambled (6, 43);
      Plain      : Sequence := Unscrambled (6);
      W, X, Y, Z : Point (1 .. 6);
      Ok         : Boolean;
      Differs    : Natural := 0;
   begin
      for I in 1 .. Draws loop
         Next (A, W, Ok);
         Next (B, X, Ok);
         Next (C, Y, Ok);
         Next (Plain, Z, Ok);
         Assert (W = X, "one seed, one stream: point" & I'Image);
         Differs := Differs + (if W /= Y and then W /= Z then 1 else 0);
      end loop;
      Assert (Differs = Draws, "two seeds, two streams:" & Differs'Image);
   end Test_Seeds;

   type Block_Access is access Block;

   procedure Free is new Ada.Unchecked_Deallocation (Block, Block_Access);

   --  Whether coordinate J of B, cut into 2**M equal intervals, has
   --  exactly one point in each: then no two points share an interval.
   function Column_Stratified
     (B : Block; M : Block_Exponent; J : Dimension) return Boolean
   is
      type Seen is array (Unsigned_32 range <>) of Boolean;
      Hit  : Seen (0 .. 2**M - 1) := [others => False];
      Cell : Unsigned_32;
   begin
      for I in B'Range (1) loop
         Cell := Shift_Right (B (I, J), Bits - M);
         if Hit (Cell) then
            return False;
         end if;
         Hit (Cell) := True;
      end loop;
      return True;
   end Column_Stratified;

   --  Whether every coordinate of B, 2**M points, is stratified.
   function Stratified (B : Block; M : Block_Exponent) return Boolean
   is (for all J in B'Range (2) => Column_Stratified (B, M, J));

   --  Two blocks of 2**10 points in 12 dimensions, scrambled: each puts
   --  one point in each of 2**10 equal intervals of every coordinate, and
   --  they are the points Next gives.
   procedure Test_Blocks (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      M      : constant := 10;
      D      : constant := 12;
      S      : Sequence := Abacus.Sobol.Scrambled (D, 7);
      One_By : Sequence := Abacus.Sobol.Scrambled (D, 7);
      B      : Block_Access := new Block (1 .. 2**M, 1 .. D);
      X      : Point (1 .. D);
      Result : Block_Result;
      Ok     : Boolean;
   begin
      for Round in 1 .. 2 loop
         Next_Block (S, M, B.all, Result);
         Assert (Result = Filled, "filled");
         Assert (Stratified (B.all, M), "stratified, block" & Round'Image);
         for I in B'Range (1) loop
            Next (One_By, X, Ok);
            Assert
              ((for all J in 1 .. D => B (I, J) = X (J)), "point" & I'Image);
         end loop;
      end loop;
      Assert (Drawn (S) = 2 * 2**M, "two blocks drawn");
      Free (B);
   end Test_Blocks;

   --  A block that does not start at a multiple of its size, or that
   --  starts past the last point, is refused by name and the sequence
   --  left.  An aligned block that starts before the end fits: 2**32 is a
   --  multiple of every block's size.
   procedure Test_Block_Refused (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      S      : Sequence := Abacus.Sobol.Scrambled (2, 7);
      B      : Block (1 .. 8, 1 .. 2);
      Four   : Block (1 .. 4, 1 .. 2);
      X      : Point (1 .. 2);
      Result : Block_Result;
      Ok     : Boolean;
   begin
      Next (S, X, Ok);
      Next_Block (S, 3, B, Result);
      Assert (Result = Misaligned and then Drawn (S) = 1, "misaligned");
      Skip (S, Period - 5, Ok);
      Next_Block (S, 2, Four, Result);
      Assert (Result = Filled and then Drawn (S) = Period, "the last four");
      Next_Block (S, 3, B, Result);
      Assert (Result = Past_End and then Drawn (S) = Period, "past the end");
   end Test_Block_Refused;

   --  A coordinate as a value on the grid: over 2**32 is over 2**40, a
   --  shift by eight, so every coordinate is a value in [0, 1).
   procedure Test_Unit (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use Abacus;
   begin
      Assert (Unit (0) = 0, "zero");
      Assert (Unit (2**31) = One / 2, "a half");
      Assert (Unit (Coordinate'Last) = One - 2**8, "the last below one");
   end Test_Unit;

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
      Register_Routine
        (T, Test_Scrambled'Access, "The scramble, as a second implementation");
      Register_Routine (T, Test_Seeds'Access, "One seed, one stream");
      Register_Routine (T, Test_Blocks'Access, "Blocks of 2**k, stratified");
      Register_Routine (T, Test_Block_Refused'Access, "A block refused");
      Register_Routine (T, Test_Unit'Access, "A coordinate as a value");
   end Register_Tests;

   overriding
   function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("Abacus.Sobol");
   end Name;

end Abacus_Sobol_Tests;
