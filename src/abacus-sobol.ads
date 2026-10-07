with Interfaces;

--  Sobol sequences: points in [0, 1)**D, D up to 64, each coordinate an
--  integer over 2**32.  The direction numbers are Joe and Kuo's
--  (criterion D(6)), and the points come in Gray-code order, each the
--  last with one direction number xored in.  A scrambled sequence is
--  scipy's method -- a linear matrix scramble and a digital shift -- with
--  abacus's seeded generator, so it is not scipy's stream.  A sequence is
--  an object the caller holds: its direction numbers, its shift and the
--  count drawn travel in it.

package Abacus.Sobol
  with SPARK_Mode, Pure
is

   use type Interfaces.Unsigned_32;
   use type Interfaces.Unsigned_64;

   Max_Dimension : constant := 64;
   subtype Dimension is Positive range 1 .. Max_Dimension;

   --  The digits of a coordinate.
   Bits : constant := 32;

   --  A coordinate in [0, 1), times 2**32.
   subtype Coordinate is Interfaces.Unsigned_32;

   type Point is array (Dimension range <>) of Coordinate;

   --  How many points a sequence holds, and so the most a count reaches.
   Period : constant := 2**Bits;
   subtype Point_Count is Interfaces.Unsigned_64 range 0 .. Period;

   type Sequence (D : Dimension) is private;

   --  The sequence in D dimensions as published, its first point zero.
   function Unscrambled (D : Dimension) return Sequence;

   --  The sequence in D dimensions scrambled from Seed: each dimension's
   --  direction numbers multiplied by a random unit lower-triangular
   --  binary matrix (each digit becomes itself xor some of the digits
   --  above it), and every point xored with a random shift, the first
   --  point.  Both send each elementary interval onto one, so the
   --  points stay as evenly spread; a seed gives one stream.
   function Scrambled
     (D : Dimension; Seed : Interfaces.Unsigned_64) return Sequence;

   --  How many points have been drawn from S.
   function Drawn (S : Sequence) return Point_Count;

   --  The next point into X, and Ok; Ok is False, and S and X left at
   --  zero, once every point has been drawn.
   procedure Next (S : in out Sequence; X : out Point; Ok : out Boolean)
   with
     Pre  => X'First = 1 and then X'Last = S.D,
     Post =>
       Ok = (Drawn (S'Old) < Period)
       and then Drawn (S) = (if Ok then Drawn (S'Old) + 1 else Drawn (S'Old));

   --  Count points passed over without being drawn, Ok; Ok is False, and
   --  S left as it was, when fewer than Count remain.  The point reached
   --  is made at once from the Gray code of its index.
   procedure Skip (S : in out Sequence; Count : Point_Count; Ok : out Boolean)
   with
     Post =>
       Ok = (Count <= Period - Drawn (S'Old))
       and then (if Ok then Drawn (S) = Drawn (S'Old) + Count else S = S'Old);

   --  A block of 2**M points, one per row: M up to 30.
   Max_Block_Exponent : constant := 30;
   subtype Block_Exponent is Natural range 0 .. Max_Block_Exponent;

   function Block_Size (M : Block_Exponent) return Positive
   is (2**M);

   type Block is array (Positive range <>, Dimension range <>) of Coordinate;

   --  How a block was drawn: filled; refused because the count drawn is
   --  not a multiple of the block's size, so its points would not be
   --  stratified; or refused because every point has been drawn.  An
   --  aligned block that starts before the end always fits, 2**32 being a
   --  multiple of its size.
   type Block_Result is (Filled, Misaligned, Past_End);

   --  The next 2**M points into B's rows, as scipy's random_base2 draws
   --  them.  A filled block of a sequence drawn so far in whole blocks
   --  puts one point in each of 2**M equal intervals of every
   --  coordinate.  Refused, S is left as it was.
   procedure Next_Block
     (S      : in out Sequence;
      M      : Block_Exponent;
      B      : out Block;
      Result : out Block_Result)
   with
     Pre  =>
       B'First (1) = 1
       and then B'Last (1) = Block_Size (M)
       and then B'First (2) = 1
       and then B'Last (2) = S.D,
     Post =>
       (if Result = Filled
        then Drawn (S) = Drawn (S'Old) + Point_Count (Block_Size (M))
        else S = S'Old);

   --  A coordinate as a value on the grid, in [0, 1): over 2**32 is over
   --  2**40, a shift by eight.
   function Unit (C : Coordinate) return Val
   is (Val (C) * 2**(Frac - Bits))
   with Post => Unit'Result in 0 .. One - 1;

private

   subtype Digit is Positive range 1 .. Bits;

   --  A dimension's direction numbers, left-aligned: number K has its
   --  leading digit K places below the point.
   type Direction_Numbers is array (Digit) of Coordinate;
   type Direction_Table is array (Dimension range <>) of Direction_Numbers;

   --  The direction numbers, the shift (the first point), the point the
   --  next draw returns, and the count drawn.
   type Sequence (D : Dimension) is record
      V       : Direction_Table (1 .. D);
      Shift   : Point (1 .. D);
      Current : Point (1 .. D);
      Count   : Point_Count;
   end record;

   function Drawn (S : Sequence) return Point_Count
   is (S.Count);

end Abacus.Sobol;
