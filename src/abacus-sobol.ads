with Interfaces;

--  Sobol sequences: points in [0, 1)**D, D up to 64, each coordinate an
--  integer over 2**32.  The direction numbers are Joe and Kuo's
--  (criterion D(6)), and the points come in Gray-code order, each the
--  last with one direction number xored in.  A sequence is an object the
--  caller holds: its direction numbers and the count drawn travel in it.

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

private

   subtype Digit is Positive range 1 .. Bits;

   --  A dimension's direction numbers, left-aligned: number K has its
   --  leading digit K places below the point.
   type Direction_Numbers is array (Digit) of Coordinate;
   type Direction_Table is array (Dimension range <>) of Direction_Numbers;

   --  The direction numbers, the point the next draw returns, and the
   --  count drawn.
   type Sequence (D : Dimension) is record
      V       : Direction_Table (1 .. D);
      Current : Point (1 .. D);
      Count   : Point_Count;
   end record;

   function Drawn (S : Sequence) return Point_Count
   is (S.Count);

end Abacus.Sobol;
