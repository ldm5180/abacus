with Ada.Unchecked_Deallocation;
with Interfaces;

with AUnit.Assertions; use AUnit.Assertions;

with Abacus;         use Abacus;
with Abacus.Random;
with Abacus.Sorting; use Abacus.Sorting;

package body Abacus_Sorting_Tests is

   --  A sort returns the values in order and the permutation that took
   --  them there.
   procedure Test_Sort (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      V     : Long_Vector := [5, -1, 3, 3, 0];
      Order : Order_Array (V'Range);
   begin
      Sort (V, Order);
      Assert (V = [-1, 0, 3, 3, 5], "in order");
      Assert (Order = [2, 5, 3, 4, 1], "the permutation, ties in place");
   end Test_Sort;

   --  Equal values fall back to the caller's key, then to their places.
   procedure Test_Keys (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      V     : constant Long_Vector := [7, 7, 7, 1];
      Keys  : constant Long_Vector := [3, 1, 3, 9];
      Order : Order_Array (V'Range);
   begin
      Sort_Order (V, Keys, Order);
      Assert (Order = [4, 2, 1, 3], "by value, then key, then place");
   end Test_Keys;

   --  A rank is an element's place in the sorted order.
   procedure Test_Rank (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      V     : constant Long_Vector := [30, 10, 20, 10];
      Ranks : Order_Array (V'Range);
   begin
      Rank (V, [0, 0, 0, 0], Ranks);
      Assert (Ranks = [4, 1, 3, 2], "ranks, ties by place");
      Rank (V, [0, 5, 0, 1], Ranks);
      Assert (Ranks = [4, 2, 3, 1], "ranks, ties by key");
   end Test_Rank;

   --  The nearest rule takes the element at round (q (n - 1)); the linear
   --  rule interpolates between the two around it.
   procedure Test_Quantile (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Data : constant Long_Vector := [One, 2 * One, 3 * One, 4 * One];
   begin
      Assert (Quantile (Data, One / 2, Nearest) = 3 * One, "median, nearest");
      Assert
        (Quantile (Data, One / 2, Linear) = 5 * One / 2, "median, linear");
      Assert (Quantile (Data, 0, Nearest) = One, "the least");
      Assert (Quantile (Data, One, Nearest) = 4 * One, "the most");
      Assert (Quantile (Data, One, Linear) = 4 * One, "the most, linear");
      Assert (Quantile (Data, One / 4, Linear) = 7 * One / 4, "a quarter");
      Assert
        (Quantile (Data, One / 4, Nearest) = 2 * One, "a quarter, nearest");
      Assert
        (Quantile ([Val'Last], One / 3, Linear) = Val'Last, "one element");
   end Test_Quantile;

   --  A million elements: far past Max_N, and only a few distinct values
   --  and keys, so most places tie on both and fall to their place.
   Large : constant := 1_000_000;

   --  The seed of the values; the keys take another.
   Seed : constant := 20261006;

   type Values_Access is access Long_Vector;
   type Order_Access is access Order_Array;
   type Seen_Array is array (Place range <>) of Boolean;
   type Seen_Access is access Seen_Array;

   procedure Free is new
     Ada.Unchecked_Deallocation (Long_Vector, Values_Access);
   procedure Free is new
     Ada.Unchecked_Deallocation (Order_Array, Order_Access);
   procedure Free is new Ada.Unchecked_Deallocation (Seen_Array, Seen_Access);

   --  N seeded draws in -Spread .. Spread - 1 (in units).
   function Drawn
     (Seed : Interfaces.Unsigned_64; Spread : Val) return Values_Access
   is
      use type Interfaces.Unsigned_64;
      G : Abacus.Random.Generator := Abacus.Random.Seeded (Seed);
      X : Interfaces.Unsigned_64;
      V : constant Values_Access := new Long_Vector (1 .. Large);
   begin
      for K in V'Range loop
         Abacus.Random.Below (G, Interfaces.Unsigned_64 (2 * Spread), X);
         V (K) := Val (X) - Spread;
      end loop;
      return V;
   end Drawn;

   --  Whether Order lists every place exactly once.
   function Each_Once (Order : Order_Array) return Boolean is
      Seen : Seen_Access := new Seen_Array'(Order'Range => False);
      Ok   : Boolean := True;
   begin
      for P of Order loop
         Ok := Ok and then P in Order'Range and then not Seen (P);
         exit when not Ok;
         Seen (P) := True;
      end loop;
      Free (Seen);
      return Ok;
   end Each_Once;

   --  A large seeded input sorts in the order value, key, place, and the
   --  order is a permutation; the scratch is the caller's, from the heap.
   procedure Test_Large (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Values  : Values_Access := Drawn (Seed, 50);
      Keys    : Values_Access := Drawn (7, 3);
      Order   : Order_Access := new Order_Array (1 .. Large);
      Scratch : Order_Access := new Order_Array (1 .. Large);
   begin
      Sort_Order (Values.all, Keys.all, Order.all, Scratch.all);
      Assert (Each_Once (Order.all), "a permutation");
      for K in 1 .. Large - 1 loop
         Assert
           (Precedes (Values.all, Keys.all, Order (K), Order (K + 1)),
            "in order at" & K'Image);
      end loop;
      Free (Values);
      Free (Keys);
      Free (Order);
      Free (Scratch);
   end Test_Large;

   overriding
   procedure Register_Tests (T : in out Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine (T, Test_Sort'Access, "A sort and its permutation");
      Register_Routine (T, Test_Keys'Access, "Ties by key, then place");
      Register_Routine (T, Test_Rank'Access, "Ranks");
      Register_Routine (T, Test_Quantile'Access, "Quantiles by both rules");
      Register_Routine (T, Test_Large'Access, "A million seeded elements");
   end Register_Tests;

   overriding
   function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("Abacus.Sorting");
   end Name;

end Abacus_Sorting_Tests;
