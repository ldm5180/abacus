with Abacus.Arith;
with Abacus.Text.Scanner; use Abacus.Text.Scanner;

package body Abacus.Text
  with SPARK_Mode
is

   --  The largest whole part a value holds.
   Whole_Bound : constant := Val_Bound / One;

   subtype Whole_Value is Wide range 0 .. Whole_Bound;

   --  Where the point stands once the exponent has moved it: how many of
   --  the figures precede it, which may be none or more than there are.
   subtype Point_Position is
     Integer range -Max_Exponent .. Max_Text + Max_Exponent;

   function Point_Of (N : Number) return Point_Position
   is (if N.Exp_Negative then N.Whole - N.Exponent else N.Whole + N.Exponent);

   --  Figure K of the number, zero outside its figures.
   function Figure (N : Number; K : Integer) return Digit
   is (if K in 1 .. N.Count then N.Figures (K) else 0);

   --  The figures before the point, as a whole number; Fits is False
   --  once it passes Whole_Bound.
   type Whole_Part is record
      Value : Whole_Value := 0;
      Fits  : Boolean := True;
   end record;

   function Whole_Of (N : Number; P : Point_Position) return Whole_Part is
      W : Wide := 0;
   begin
      for K in 1 .. P loop
         W := W * 10 + Wide (Figure (N, K));
         if W > Whole_Bound then
            return (Value => 0, Fits => False);
         end if;
         pragma Loop_Invariant (W in Whole_Value);
      end loop;
      return (Value => W, Fits => True);
   end Whole_Of;

   --  One more bit than the grid: enough to round to it, ties included.
   Scale_41 : constant := 2 * One;

   --  A fraction below 10**(-Below_Grid) is under half a unit, so it
   --  rounds to zero whatever its figures.
   Below_Grid : constant := 13;

   --  How many figures the fraction has after the point: none when it
   --  is below the grid.
   function Fraction_Digits (N : Number; P : Point_Position) return Natural
   is (if N.Count <= P or else P < -Below_Grid then 0 else N.Count - P)
   with Post => Fraction_Digits'Result <= Max_Text + Below_Grid;

   --  floor (F * 2**41) for the fraction F = 0.f1 f2 ... fn after the
   --  point, exactly: from the last figure to the first, each figure
   --  times 2**41 plus the carry from the one after it, over ten.
   function Scaled_Fraction (N : Number; P : Point_Position) return Raw is
      Carry : Raw := 0;
   begin
      for K in reverse 1 .. Fraction_Digits (N, P) loop
         Carry := (Raw (Figure (N, P + K)) * Scale_41 + Carry) / 10;
         pragma Loop_Invariant (Carry in 0 .. Scale_41 - 1);
      end loop;
      return Carry;
   end Scaled_Fraction;

   function Refusal (Error : Error_Kind; Position : Natural := 0) return Read
   is ((Ok => False, Value => 0, Error => Error, Position => Position))
   with Pre => Error /= None;

   --  The value N names: its whole part times One, plus its fraction
   --  rounded to the grid, which is floor (F * 2**41) + 1 halved.
   function Assemble (N : Number) return Read
   with
     Post =>
       (if Assemble'Result.Ok
        then Assemble'Result.Error = None
        else Assemble'Result.Value = 0 and then Assemble'Result.Error /= None)
   is
      P     : constant Point_Position := Point_Of (N);
      W     : constant Whole_Part := Whole_Of (N, P);
      Units : Wide;
   begin
      if not W.Fits then
         return Refusal (Out_Of_Range);
      end if;
      Units := W.Value * One + Wide (Scaled_Fraction (N, P) + 1) / 2;
      if Units > Val_Bound then
         return Refusal (Out_Of_Range);
      end if;
      return
        (Ok       => True,
         Value    => Val (if N.Negative then -Units else Units),
         Error    => None,
         Position => 0);
   end Assemble;

   function Parse (Text : String) return Read is
      S : Scan_Result;
   begin
      if Text'Length = 0 then
         return Refusal (Empty);
      elsif Text'Length > Max_Text then
         return Refusal (Too_Long);
      end if;
      S := Scan (Text);
      return
        (if S.Ok then Assemble (S.Number) else Refusal (S.Error, S.Position));
   end Parse;

   ---------------------------------------------------------------------
   --  Writing.
   ---------------------------------------------------------------------

   subtype Power_Of_Ten is Wide range 1 .. 10**Max_Places;

   Powers : constant array (Place_Count) of Power_Of_Ten :=
     [for K in Place_Count => 10**K];

   subtype Fraction_Units is Wide range 0 .. One - 1;

   --  F units at K places: round (F * 10**K / 2**40), which is at most
   --  10**K because F is under one; the clamp states that without a
   --  nonlinear proof, and never binds.
   function At_Places (F : Fraction_Units; K : Place_Count) return Wide
   is (Wide'Min (Arith.Div_Round (F * Powers (K), One), Powers (K)))
   with Post => At_Places'Result in 0 .. Powers (K);

   --  Whether D at K places reads back as F units.
   function Reads_Back
     (D : Wide; K : Place_Count; F : Fraction_Units) return Boolean
   is (Arith.Div_Round (D * One, Powers (K)) = F)
   with Pre => D in 0 .. Powers (K);

   --  The fewest places, up to Places, at which F reads back; Places
   --  when none does.
   function Fewest_Places
     (F : Fraction_Units; Places : Place_Count) return Place_Count is
   begin
      for K in 0 .. Places loop
         if Reads_Back (At_Places (F, K), K, F) then
            return K;
         end if;
      end loop;
      return Places;
   end Fewest_Places;

   subtype Image_Length is Natural range 0 .. Max_Image;

   --  A text as it is written, left to right.
   type Buffer is record
      Text : String (1 .. Max_Image) := [others => ' '];
      Last : Image_Length := 0;
   end record;

   --  X in Width figures, zero-padded on the left.
   procedure Put (B : in out Buffer; X : Wide; Width : Positive)
   with
     Pre  =>
       X in 0 .. Powers (Place_Count'Min (Width, Max_Places)) - 1
       and then B.Last <= Max_Image - Width,
     Post => B.Last = B.Last'Old + Width
   is
      Rest : Wide := X;
   begin
      for I in reverse B.Last + 1 .. B.Last + Width loop
         B.Text (I) := Character'Val (Character'Pos ('0') + Rest mod 10);
         Rest := Rest / 10;
      end loop;
      B.Last := B.Last + Width;
   end Put;

   procedure Put (B : in out Buffer; C : Character)
   with Pre => B.Last < Max_Image, Post => B.Last = B.Last'Old + 1
   is
   begin
      B.Last := B.Last + 1;
      B.Text (B.Last) := C;
   end Put;

   --  The most figures a whole part takes.
   Whole_Width : constant := 6;

   --  How many figures X takes in decimal.
   function Width_Of (X : Wide) return Positive
   with
     Pre  => X in 0 .. Whole_Bound + 1,
     Post =>
       Width_Of'Result <= Whole_Width and then X < Powers (Width_Of'Result)
   is
   begin
      for W in 1 .. Whole_Width - 1 loop
         if X < Powers (W) then
            return W;
         end if;
      end loop;
      return Whole_Width;
   end Width_Of;

   function Image (V : Val; Places : Place_Count := Max_Places) return String
   is
      Magnitude : constant Wide := (if V < 0 then -Wide (V) else Wide (V));
      F         : constant Fraction_Units := Magnitude mod One;
      K         : constant Place_Count := Fewest_Places (F, Places);
      D         : constant Wide := At_Places (F, K);
      Carry     : constant Wide := (if D = Powers (K) then 1 else 0);
      Whole     : constant Wide := Magnitude / One + Carry;
      B         : Buffer;
   begin
      if V < 0 and then (Whole > 0 or else D > 0) then
         Put (B, '-');
      end if;
      Put (B, Whole, Width_Of (Whole));
      if K > 0 then
         Put (B, '.');
         Put (B, D - Carry * Powers (K), K);
      end if;
      return B.Text (1 .. B.Last);
   end Image;

end Abacus.Text;
