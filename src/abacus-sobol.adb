with Abacus.Random;
with Abacus.Sobol.Directions;

package body Abacus.Sobol
  with SPARK_Mode
is

   use Interfaces;

   --  Dimension 1's direction numbers: number K is 2**(32 - K).
   function First_Directions return Direction_Numbers
   is ([for K in Digit => Shift_Left (1, Bits - K)]);

   --  Dimension J's direction numbers from its polynomial's degree S,
   --  inner coefficients A and initial numbers M, by the recurrence
   --  V (K) = V (K - S) xor V (K - S) / 2**S xor the a_i V (K - i).
   function Listed_Directions (J : Directions.Listed) return Direction_Numbers
   is
      use Abacus.Sobol.Directions;
      S : constant Degree_Value := Degree (J);
      A : constant Natural := Coded (J);
      V : Direction_Numbers := [others => 0];
   begin
      for K in 1 .. S loop
         V (K) := Shift_Left (Unsigned_32 (Initial (J, K)), Bits - K);
      end loop;
      for K in S + 1 .. Digit'Last loop
         V (K) := V (K - S) xor Shift_Right (V (K - S), S);
         for I in 1 .. S - 1 loop
            if (A / 2**(S - 1 - I)) mod 2 = 1 then
               V (K) := V (K) xor V (K - I);
            end if;
         end loop;
      end loop;
      return V;
   end Listed_Directions;

   function Directions_Of (J : Dimension) return Direction_Numbers
   is (if J = 1 then First_Directions else Listed_Directions (J));

   function Unscrambled (D : Dimension) return Sequence
   is ((D       => D,
        V       => [for J in 1 .. D => Directions_Of (J)],
        Shift   => [others => 0],
        Current => [others => 0],
        Count   => 0));

   ---------------------------------------------------------------------
   --  The scramble.
   ---------------------------------------------------------------------

   --  A digit's place in a coordinate: place 31 is the leading digit.
   subtype Place is Natural range 0 .. Bits - 1;

   --  One row of a lower-triangular binary matrix per place: which input
   --  digits the output digit at that place is the xor of -- itself and
   --  some of those above it.
   type Matrix_Rows is array (Place) of Coordinate;

   --  Whether X has an odd number of ones.
   function Odd (X : Coordinate) return Boolean is
      Y : Coordinate := X;
   begin
      Y := Y xor Shift_Right (Y, 16);
      Y := Y xor Shift_Right (Y, 8);
      Y := Y xor Shift_Right (Y, 4);
      Y := Y xor Shift_Right (Y, 2);
      Y := Y xor Shift_Right (Y, 1);
      return (Y and 1) = 1;
   end Odd;

   --  V multiplied by the matrix whose rows are L.
   function Times (L : Matrix_Rows; V : Coordinate) return Coordinate is
      Result : Coordinate := 0;
   begin
      for P in Place loop
         if Odd (L (P) and V) then
            Result := Result or Shift_Left (1, P);
         end if;
      end loop;
      return Result;
   end Times;

   --  The low 32 bits of the next draw.
   procedure Draw (G : in out Abacus.Random.Generator; X : out Coordinate) is
      Wide_Draw : Unsigned_64;
   begin
      Abacus.Random.Next (G, Wide_Draw);
      X := Coordinate (Wide_Draw and (Period - 1));
   end Draw;

   --  A random unit lower-triangular matrix: at each place a one, ones at
   --  random among the places above, none below.  The leading place has
   --  none above, and takes no draw.
   procedure Draw_Matrix
     (G : in out Abacus.Random.Generator; L : out Matrix_Rows)
   is
      Row : Coordinate;
   begin
      L := [others => 0];
      for P in Place'First .. Place'Last - 1 loop
         Draw (G, Row);
         L (P) := (Row and not (Shift_Left (2, P) - 1)) or Shift_Left (1, P);
      end loop;
      L (Place'Last) := Shift_Left (1, Place'Last);
   end Draw_Matrix;

   function Scrambled
     (D : Dimension; Seed : Interfaces.Unsigned_64) return Sequence
   is
      G : Abacus.Random.Generator := Abacus.Random.Seeded (Seed);
      L : Matrix_Rows;
   begin
      return S : Sequence := Unscrambled (D) do
         for J in 1 .. D loop
            Draw (G, S.Shift (J));
            Draw_Matrix (G, L);
            for K in Digit loop
               S.V (J) (K) := Times (L, S.V (J) (K));
            end loop;
         end loop;
         S.Current := S.Shift;
      end return;
   end Scrambled;

   --  The digit the point after the one at index N differs in: one more
   --  than how many low bits of N are one.
   function Changed_Digit (N : Point_Count) return Digit
   with Pre => N < Period - 1
   is
      C : Digit := 1;
   begin
      while C < Bits and then (Shift_Right (N, C - 1) and 1) = 1 loop
         pragma Loop_Invariant (C in 1 .. Bits - 1);
         pragma Loop_Variant (Increases => C);
         C := C + 1;
      end loop;
      return C;
   end Changed_Digit;

   --  The point at index N: the xor of the direction numbers the Gray
   --  code of N names, digit K for bit K - 1.
   function Point_At (S : Sequence; N : Point_Count) return Point
   with Post => Point_At'Result'First = 1 and then Point_At'Result'Last = S.D
   is
      Gray : constant Unsigned_64 := N xor Shift_Right (N, 1);
      X    : Point (1 .. S.D) := S.Shift;
   begin
      for K in Digit loop
         if (Shift_Right (Gray, K - 1) and 1) = 1 then
            for J in 1 .. S.D loop
               X (J) := X (J) xor S.V (J) (K);
            end loop;
         end if;
      end loop;
      return X;
   end Point_At;

   procedure Skip (S : in out Sequence; Count : Point_Count; Ok : out Boolean)
   is
   begin
      Ok := Count <= Period - S.Count;
      if Ok then
         S.Count := S.Count + Count;
         S.Current :=
           (if S.Count < Period then Point_At (S, S.Count) else S.Current);
      end if;
   end Skip;

   procedure Next (S : in out Sequence; X : out Point; Ok : out Boolean) is
   begin
      X := [others => 0];
      Ok := S.Count < Period;
      if not Ok then
         return;
      end if;
      X := S.Current;
      if S.Count < Period - 1 then
         for J in 1 .. S.D loop
            S.Current (J) :=
              S.Current (J) xor S.V (J) (Changed_Digit (S.Count));
         end loop;
      end if;
      S.Count := S.Count + 1;
   end Next;

   --  B's rows filled by Next, every one of them a point: the caller has
   --  shown that as many remain.
   procedure Fill (S : in out Sequence; B : out Block)
   with
     Pre  =>
       B'First (1) = 1
       and then B'Last (1) >= 1
       and then B'First (2) = 1
       and then B'Last (2) = S.D
       and then Point_Count (B'Last (1)) <= Period - Drawn (S),
     Post => Drawn (S) = Drawn (S'Old) + Point_Count (B'Last (1))
   is
      D  : constant Dimension := S.D;
      X  : Point (1 .. D);
      Ok : Boolean;
   begin
      B := [others => [others => 0]];
      for I in B'Range (1) loop
         Next (S, X, Ok);
         pragma Assert (Ok);
         for J in X'Range loop
            B (I, J) := X (J);
         end loop;
         pragma
           Loop_Invariant (Drawn (S) = Drawn (S'Loop_Entry) + Point_Count (I));
      end loop;
   end Fill;

   procedure Next_Block
     (S      : in out Sequence;
      M      : Block_Exponent;
      B      : out Block;
      Result : out Block_Result)
   is
      Size : constant Point_Count := Point_Count (Block_Size (M));
   begin
      B := [others => [others => 0]];
      if S.Count mod Size /= 0 then
         Result := Misaligned;
      elsif Period - S.Count < Size then
         Result := Past_End;
      else
         Fill (S, B);
         Result := Filled;
      end if;
   end Next_Block;

end Abacus.Sobol;
