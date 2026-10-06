with Abacus.Arith;

package body Abacus.Sorting
  with SPARK_Mode
is

   --  Whether Order lists places First .. Last of Values in the sort's
   --  order, pair by adjacent pair.
   function Sorted_Between
     (Values, Keys : Vector; Order : Order_Array; First, Last : Natural)
      return Boolean
   is (for all K in First .. Last - 1 =>
         Precedes (Values, Keys, Order (K), Order (K + 1)))
   with
     Pre =>
       Keys'First = Values'First
       and then Keys'Last = Values'Last
       and then Order'First = Values'First
       and then Order'Last = Values'Last
       and then (for all K in Order'Range => Order (K) in Values'Range)
       and then (if First <= Last
                 then First >= Order'First and then Last <= Order'Last);

   procedure Swap (P : in out Order_Array; I, J : Index)
   with
     Pre  => I in P'Range and then J in P'Range,
     Post =>
       P (I) = P'Old (J)
       and then P (J) = P'Old (I)
       and then (for all K in P'Range =>
                   (if K /= I and then K /= J then P (K) = P'Old (K)))
   is
      Held : constant Index := P (I);
   begin
      P (I) := P (J);
      P (J) := Held;
   end Swap;

   --  Order (I) sunk into the sorted places before it, by adjacent swaps:
   --  an element moves past another only when it strictly precedes it,
   --  which is what keeps the sort stable.
   procedure Sink
     (Values, Keys : Vector; Order : in out Order_Array; I : Index)
   with
     Pre  =>
       Keys'First = Values'First
       and then Keys'Last = Values'Last
       and then Order'First = Values'First
       and then Order'Last = Values'Last
       and then I in Order'Range
       and then Is_Permutation (Order)
       and then Sorted_Between (Values, Keys, Order, Order'First, I - 1),
     Post =>
       Is_Permutation (Order)
       and then Sorted_Between (Values, Keys, Order, Order'First, I)
   is
      J : Index := I;
   begin
      while J > Order'First
        and then Precedes (Values, Keys, Order (J), Order (J - 1))
      loop
         Swap (Order, J, J - 1);
         J := J - 1;
         pragma Loop_Invariant (J in Order'First .. I);
         pragma Loop_Invariant (Is_Permutation (Order));
         pragma
           Loop_Invariant
             (Sorted_Between (Values, Keys, Order, Order'First, J - 1));
         pragma Loop_Invariant (Sorted_Between (Values, Keys, Order, J, I));
         pragma
           Loop_Invariant
             (if J > Order'First and then J < I
                then Precedes (Values, Keys, Order (J - 1), Order (J + 1)));
      end loop;
   end Sink;

   procedure Sort_Order (Values, Keys : Vector; Order : out Order_Array) is
   begin
      Order := [for K in Order'Range => K];
      pragma Assert (Is_Permutation (Order));
      for I in Order'Range loop
         Sink (Values, Keys, Order, I);
         pragma Loop_Invariant (Is_Permutation (Order));
         pragma
           Loop_Invariant
             (Sorted_Between (Values, Keys, Order, Order'First, I));
      end loop;
   end Sort_Order;

   procedure Sort (Values : in out Vector; Order : out Order_Array) is
      Keys   : constant Vector (Values'Range) := [others => 0];
      Before : constant Vector := Values;
   begin
      Sort_Order (Before, Keys, Order);
      for K in Values'Range loop
         Values (K) := Before (Order (K));
         pragma
           Loop_Invariant
             (for all L in Values'First .. K =>
                Values (L) = Before (Order (L)));
      end loop;
   end Sort;

   procedure Rank (Values, Keys : Vector; Ranks : out Order_Array) is
      Order : Order_Array (Values'Range);
   begin
      Sort_Order (Values, Keys, Order);
      Ranks := [others => Ranks'First];
      for K in Order'Range loop
         Ranks (Order (K)) := K;
      end loop;
   end Rank;

   --  Q (n - 1) for n elements, at scale One.
   function Position (Q : Probability; N : Positive) return Wide
   is (Wide (Q) * Wide (N - 1))
   with Pre => N <= Max_N, Post => Position'Result in 0 .. Wide (N - 1) * One;

   --  The line from A to B at Fraction (at scale One) of the way.
   function Between (A, B : Val; Fraction : Wide) return Val
   is (Val
         (Wide (A)
          + Wide'Max
              (0,
               Wide'Min
                 (Arith.Round_Shift (Fraction * Wide (B - A)), Wide (B - A)))))
   with
     Pre  => A <= B and then Fraction in 0 .. One - 1,
     Post => Between'Result in A .. B;

   function Quantile
     (Sorted : Vector; Q : Probability; How : Method) return Val
   is
      H    : constant Wide := Position (Q, Sorted'Length);
      Near : constant Index :=
        Sorted'First + Natural (Arith.Div_Round (H, One));
      Low  : constant Index := Sorted'First + Natural (H / One);
   begin
      if How = Nearest or else Low = Sorted'Last then
         return Sorted (if How = Nearest then Near else Low);
      end if;
      return Between (Sorted (Low), Sorted (Low + 1), H mod One);
   end Quantile;

end Abacus.Sorting;
