with Abacus.Arith;

--  A private type per instance for one kind of quantity, held between
--  First and Last: two kinds cannot be added by mistake, and a sum that
--  would leave the range is a precondition the caller proves.  The
--  instance offers its conversions; a consumer that instantiates it in a
--  private part chooses which of them to expose.

generic
   First : Val := Val'First;
   Last : Val := Val'Last;
package Abacus.Quantities with SPARK_Mode, Pure is

   --  The values a quantity of this kind may hold.
   subtype Held is Val range First .. Last;

   type Quantity is private;

   --  A quantity's value before it is set: zero when the range holds
   --  zero, and the nearest end of the range otherwise.
   function Initial return Quantity;

   function To_Quantity (V : Held) return Quantity;

   --  A quantity's value, in units of the grid.
   function Units (Q : Quantity) return Held;

   --  Whether a raw result is a value of this kind.
   function Holds (W : Wide) return Boolean
   is (W in Wide (First) .. Wide (Last));

   function "+" (L, R : Quantity) return Quantity
   with Pre => Holds (Wide (Units (L)) + Wide (Units (R)));

   function "-" (L, R : Quantity) return Quantity
   with Pre => Holds (Wide (Units (L)) - Wide (Units (R)));

   --  Q times a value, rounded once.
   function Scaled (Q : Quantity; By : Val) return Quantity
   with Pre => Holds (Arith.Product_Of (Units (Q), By));

   function "<" (L, R : Quantity) return Boolean;
   function "<=" (L, R : Quantity) return Boolean;
   function ">" (L, R : Quantity) return Boolean;
   function ">=" (L, R : Quantity) return Boolean;

private

   type Quantity is record
      V : Held := Held'Max (First, Held'Min (0, Last));
   end record;

   function Initial return Quantity
   is ((others => <>));

   function To_Quantity (V : Held) return Quantity
   is ((V => V));

   function Units (Q : Quantity) return Held
   is (Q.V);

   function "+" (L, R : Quantity) return Quantity
   is ((V => L.V + R.V));

   function "-" (L, R : Quantity) return Quantity
   is ((V => L.V - R.V));

   function Scaled (Q : Quantity; By : Val) return Quantity
   is ((V => Val (Arith.Product_Of (Q.V, By))));

   function "<" (L, R : Quantity) return Boolean
   is (L.V < R.V);

   function "<=" (L, R : Quantity) return Boolean
   is (L.V <= R.V);

   function ">" (L, R : Quantity) return Boolean
   is (L.V > R.V);

   function ">=" (L, R : Quantity) return Boolean
   is (L.V >= R.V);

end Abacus.Quantities;
