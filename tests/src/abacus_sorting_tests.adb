with AUnit.Assertions; use AUnit.Assertions;

with Abacus;         use Abacus;
with Abacus.Sorting; use Abacus.Sorting;

package body Abacus_Sorting_Tests is

   --  A sort returns the values in order and the permutation that took
   --  them there.
   procedure Test_Sort (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      V     : Vector := [5, -1, 3, 3, 0];
      Order : Order_Array (V'Range);
   begin
      Sort (V, Order);
      Assert (V = [-1, 0, 3, 3, 5], "in order");
      Assert (Order = [2, 5, 3, 4, 1], "the permutation, ties in place");
   end Test_Sort;

   --  Equal values fall back to the caller's key, then to their places.
   procedure Test_Keys (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      V     : constant Vector := [7, 7, 7, 1];
      Keys  : constant Vector := [3, 1, 3, 9];
      Order : Order_Array (V'Range);
   begin
      Sort_Order (V, Keys, Order);
      Assert (Order = [4, 2, 1, 3], "by value, then key, then place");
   end Test_Keys;

   --  A rank is an element's place in the sorted order.
   procedure Test_Rank (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      V     : constant Vector := [30, 10, 20, 10];
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
      Data : constant Vector := [One, 2 * One, 3 * One, 4 * One];
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

   overriding
   procedure Register_Tests (T : in out Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine (T, Test_Sort'Access, "A sort and its permutation");
      Register_Routine (T, Test_Keys'Access, "Ties by key, then place");
      Register_Routine (T, Test_Rank'Access, "Ranks");
      Register_Routine (T, Test_Quantile'Access, "Quantiles by both rules");
   end Register_Tests;

   overriding
   function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("Abacus.Sorting");
   end Name;

end Abacus_Sorting_Tests;
