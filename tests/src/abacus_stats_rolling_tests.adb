with AUnit.Assertions; use AUnit.Assertions;

with Abacus;               use Abacus;
with Abacus.Stats;         use Abacus.Stats;
with Abacus.Stats.Rolling; use Abacus.Stats.Rolling;

package body Abacus_Stats_Rolling_Tests is

   Rows : constant Matrix (1 .. 5, 1 .. 3) :=
     [[One / 100, One / 50, -3 * One / 100],
      [3 * One / 200, -One / 200, 0],
      [-One / 50, One / 100, One / 25],
      [3 * One / 100, 0, -One / 100],
      [Datum_Bound, -Datum_Bound, Datum_Bound]];

   function Row (I : Index) return Vector is
      Result : Vector (1 .. 3);
   begin
      for J in Result'Range loop
         Result (J) := Rows (I, J);
      end loop;
      return Result;
   end Row;

   --  A window over rows First .. Last, added fresh.
   function Fresh (First, Last : Index) return Window is
      W : Window (3) := Empty (3);
   begin
      for I in First .. Last loop
         Add_Row (W, Row (I));
      end loop;
      return W;
   end Fresh;

   --  Adding a row and removing the oldest leaves the sums equal, bit
   --  for bit, to a window built fresh over the rows that remain.
   procedure Test_Slide (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      W  : Window (3) := Fresh (1, 3);
      Ok : Boolean;
   begin
      Add_Row (W, Row (4));
      Remove_Row (W, Row (1), Ok);
      Assert (Ok and then W = Fresh (2, 4), "slid once");
      Add_Row (W, Row (5));
      Remove_Row (W, Row (2), Ok);
      Assert (Ok and then W = Fresh (3, 5), "slid to the bound");
      Assert
        (Covariance (W, 1, 3, Sample)
         = Covariance (Fresh (3, 5), 1, 3, Sample),
         "the covariance");
   end Test_Slide;

   --  The window's covariance is the vector one's.
   procedure Test_Agrees (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      W       : constant Window := Fresh (1, 4);
      A, B, C : Vector (1 .. 4);
   begin
      for I in 1 .. 4 loop
         A (I) := Rows (I, 1);
         B (I) := Rows (I, 2);
         C (I) := Rows (I, 3);
      end loop;
      for Kind in Divisor_Kind loop
         Assert
           (abs (Covariance (W, 1, 3, Kind) - Stats.Covariance (A, C, Kind))
            <= 1,
            "as the vectors' " & Kind'Image);
         Assert
           (abs (Variance (W, 2, Kind) - Stats.Variance (B, Kind)) <= 1,
            "variance " & Kind'Image);
      end loop;
   end Test_Agrees;

   --  A row that cannot have been in the window is refused, and the
   --  window is left as it was.
   procedure Test_Refuses (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      W      : Window (3) := Fresh (1, 1);
      Before : constant Window := W;
      Ok     : Boolean;
   begin
      Remove_Row (W, Row (5), Ok);
      Assert (not Ok and then W = Before, "a row never added");
      Remove_Row (W, Row (1), Ok);
      Assert (Ok and then W = Empty (3), "the last row");
      Remove_Row (W, Row (1), Ok);
      Assert (not Ok and then W = Empty (3), "from an empty window");
   end Test_Refuses;

   overriding
   procedure Register_Tests (T : in out Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T, Test_Slide'Access, "A slid window equals a fresh one");
      Register_Routine (T, Test_Agrees'Access, "It agrees with Abacus.Stats");
      Register_Routine
        (T, Test_Refuses'Access, "A row never added is refused");
   end Register_Tests;

   overriding
   function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("Abacus.Stats.Rolling");
   end Name;

end Abacus_Stats_Rolling_Tests;
