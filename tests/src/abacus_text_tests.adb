with AUnit.Assertions; use AUnit.Assertions;

with Abacus;      use Abacus;
with Abacus.Text; use Abacus.Text;

package body Abacus_Text_Tests is

   procedure Reads (Text : String; Units : Val; Message : String := "") is
      R : constant Read := Parse (Text);
   begin
      Assert
        (R.Ok and then R.Value = Units and then R.Error = None,
         Text
         & " reads as"
         & R.Value'Image
         & " ("
         & R.Error'Image
         & "), want"
         & Units'Image
         & " "
         & Message);
   end Reads;

   procedure Refuses (Text : String; Error : Error_Kind; Position : Natural) is
      R : constant Read := Parse (Text);
   begin
      Assert
        (not R.Ok
         and then R.Value = 0
         and then R.Error = Error
         and then R.Position = Position,
         Text
         & " gives "
         & R.Error'Image
         & " at"
         & R.Position'Image
         & ", want "
         & Error'Image
         & " at"
         & Position'Image);
   end Refuses;

   --  Signs, points, fractions and whole numbers.
   procedure Test_Plain (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Reads ("1", One);
      Reads ("-1", -One);
      Reads ("+1", One);
      Reads ("0", 0);
      Reads ("-0", 0);
      Reads ("0.5", One / 2);
      Reads (".5", One / 2);
      Reads ("-.5", -One / 2);
      Reads ("5.", 5 * One);
      Reads ("000012.250", 12 * One + One / 4);
      Reads ("131072", Val_Bound, "the largest whole value");
      Reads ("-131072", -Val_Bound);
      Reads ("0.333333333333333333333333333333", One / 3, "a long third");
   end Test_Plain;

   --  Exponents move the point either way, and saturate harmlessly.
   procedure Test_Exponent (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Quarter_Percent  : constant := 2_748_779_069;
      Hundred_Thousand : constant := 100_000 * One;
   begin
      Reads ("2.5e-3", Quarter_Percent, "0.0025");
      Reads ("25E-4", Quarter_Percent);
      Reads ("1e5", Hundred_Thousand);
      Reads ("1.31072e+5", Val_Bound);
      Reads ("0.0001e4", One);
      Reads ("1e-9999", 0, "far below the grid");
      Reads ("0e9999", 0, "zero at any exponent");
      Reads ("1e-13", 0, "under half a unit");
   end Test_Exponent;

   --  A text exactly half a unit from two values rounds away from zero;
   --  a figure less, toward the nearer.
   procedure Test_Ties (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Half_Unit : constant String :=
        "0.00000000000045474735088646411895751953125";
      Under     : constant String :=
        "0.00000000000045474735088646411895751953124";
   begin
      Reads (Half_Unit, 1, "half a unit");
      Reads ("-" & Half_Unit, -1, "minus half a unit");
      Reads (Under, 0, "just under half a unit");
      Reads ("1" & Half_Unit (2 .. Half_Unit'Last), One + 1, "one and a half");
      Reads ("4.5474735088646411895751953125e-13", 1, "with an exponent");
   end Test_Ties;

   --  Text that is not a number, with its reason and where.
   procedure Test_Refused (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Refuses ("", Empty, 0);
      Refuses ("1.2.3", Unexpected, 4);
      Refuses ("abc", Unexpected, 1);
      Refuses ("1 ", Unexpected, 2);
      Refuses ("--1", Unexpected, 2);
      Refuses ("1e+-2", Unexpected, 4);
      Refuses ("-", Incomplete, 0);
      Refuses (".", Incomplete, 0);
      Refuses ("1e", Incomplete, 0);
      Refuses ("1e-", Incomplete, 0);
      Refuses ("131073", Out_Of_Range, 0);
      Refuses ("131072.000000000001", Out_Of_Range, 0);
      Refuses ("1e6", Out_Of_Range, 0);
      Refuses ("1e9999", Out_Of_Range, 0);
      Refuses ([1 .. Max_Text + 1 => '1'], Too_Long, 0);
      Reads ([1 .. Max_Text => '0'], 0, "the longest text");
   end Test_Refused;

   procedure Writes (V : Val; Places : Place_Count; Want : String) is
      Got : constant String := Image (V, Places);
   begin
      Assert (Got = Want, V'Image & " writes as " & Got & ", want " & Want);
   end Writes;

   --  The fewest places that read back, or the value at Places.
   procedure Test_Image (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Writes (0, Max_Places, "0");
      Writes (One, Max_Places, "1");
      Writes (-One, Max_Places, "-1");
      Writes (One / 2, Max_Places, "0.5");
      Writes (-One / 4, Max_Places, "-0.25");
      Writes (Val_Bound, Max_Places, "131072");
      Writes (-Val_Bound, Max_Places, "-131072");
      Writes (1, Max_Places, "0.000000000001");
      Writes (One / 3, 4, "0.3333");
      Writes (One / 3, Max_Places, "0.333333333333");
      Writes (One - 1, 2, "1.00");
      Writes (-(One - 1), 2, "-1.00");
      Writes (-1, 5, "0.00000");
      Writes (2 * One + One / 2, 0, "3");
   end Test_Image;

   --  Every value written at the most places reads back as itself.
   procedure Test_Round_Trip (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      type Seed is mod 2**64;
      --  Knuth's MMIX generator: enough to spread the values.
      Multiplier : constant := 6_364_136_223_846_793_005;
      Increment  : constant := 1_442_695_040_888_963_407;
      Start      : constant := 20_261_006;
      Cases      : constant := 20_000;
      S          : Seed := Start;
      V          : Val;
   begin
      for I in 1 .. Cases loop
         S := S * Multiplier + Increment;
         V := Val (Raw (S / 2**7) mod (2 * Val_Bound + 1) - Val_Bound);
         if I mod 2 = 0 then
            V := V / 2**(Natural (S mod 50));
         end if;
         Assert
           (Parse (Image (V)) = (True, V, None, 0),
            V'Image & " wrote as " & Image (V));
      end loop;
   end Test_Round_Trip;

   overriding
   procedure Register_Tests (T : in out Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine (T, Test_Plain'Access, "Signs, points, fractions");
      Register_Routine (T, Test_Exponent'Access, "Exponents");
      Register_Routine (T, Test_Ties'Access, "Half a unit rounds away");
      Register_Routine (T, Test_Refused'Access, "Refusals and their reasons");
      Register_Routine (T, Test_Image'Access, "Writing");
      Register_Routine (T, Test_Round_Trip'Access, "Every value reads back");
   end Register_Tests;

   overriding
   function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("Abacus.Text");
   end Name;

end Abacus_Text_Tests;
