--  A stable sort proved to return a sorted permutation of its input,
--  ranks, and quantiles by the nearest rule and the linear one.  Ties
--  between equal values fall to a caller's key and then to the values'
--  places, so the order is the same however the data arrived.

package Abacus.Sorting
  with SPARK_Mode
is

   --  A permutation of places: Order (K) is the place, in the input, of
   --  the K-th element of the output.
   type Order_Array is array (Index range <>) of Index;

   --  Whether P maps its range onto itself one to one.
   function Is_Permutation (P : Order_Array) return Boolean
   is ((for all I in P'Range => P (I) in P'Range)
       and then (for all I in P'Range =>
                   (for all J in P'Range => (if I /= J then P (I) /= P (J)))));

   --  The total order the sort follows: by value, then by key, then by
   --  place.  No two places are equal, so no two elements tie.
   function Precedes (Values, Keys : Vector; A, B : Index) return Boolean
   is (Values (A) < Values (B)
       or else (Values (A) = Values (B)
                and then (Keys (A) < Keys (B)
                          or else (Keys (A) = Keys (B) and then A < B))))
   with
     Pre =>
       Keys'First = Values'First
       and then Keys'Last = Values'Last
       and then A in Values'Range
       and then B in Values'Range;

   --  Whether Order lists Values in that total order.
   function Sorted_By
     (Values, Keys : Vector; Order : Order_Array) return Boolean
   is (for all K in Order'Range =>
         (if K < Order'Last
          then Precedes (Values, Keys, Order (K), Order (K + 1))))
   with
     Pre =>
       Keys'First = Values'First
       and then Keys'Last = Values'Last
       and then Order'First = Values'First
       and then Order'Last = Values'Last
       and then (for all K in Order'Range => Order (K) in Values'Range);

   function Is_Sorted (V : Vector) return Boolean
   is (for all K in V'Range => (if K < V'Last then V (K) <= V (K + 1)));

   --  The order that sorts Values, ties by Keys then by place.
   procedure Sort_Order (Values, Keys : Vector; Order : out Order_Array)
   with
     Pre  =>
       Keys'First = Values'First
       and then Keys'Last = Values'Last
       and then Order'First = Values'First
       and then Order'Last = Values'Last,
     Post => Is_Permutation (Order) and then Sorted_By (Values, Keys, Order);

   --  Values sorted in place, and the permutation that took them there.
   procedure Sort (Values : in out Vector; Order : out Order_Array)
   with
     Pre  => Order'First = Values'First and then Order'Last = Values'Last,
     Post =>
       Is_Permutation (Order)
       and then Is_Sorted (Values)
       and then (for all K in Values'Range =>
                   Values (K) = Values'Old (Order (K)));

   --  Ranks (I) is the place of element I in the order Sort_Order gives:
   --  1 for the least.
   procedure Rank (Values, Keys : Vector; Ranks : out Order_Array)
   with
     Pre =>
       Keys'First = Values'First
       and then Keys'Last = Values'Last
       and then Ranks'First = Values'First
       and then Ranks'Last = Values'Last
       and then Values'First = 1;

   --  How a quantile between two elements is taken: the element at
   --  round (q (n - 1)), ties away from zero; or the line between the
   --  two elements around q (n - 1).
   type Method is (Nearest, Linear);

   subtype Probability is Val range 0 .. One;

   --  The Q quantile of sorted data.  By the nearest rule it is one of
   --  the elements; by the linear rule it lies between two neighbours.
   function Quantile
     (Sorted : Vector; Q : Probability; How : Method) return Val
   with
     Pre  => Sorted'Length > 0 and then Is_Sorted (Sorted),
     Post =>
       (if How = Nearest
        then (for some I in Sorted'Range => Quantile'Result = Sorted (I))
        else
          (for some I in Sorted'Range =>
             Quantile'Result
             in Sorted (I) .. Sorted (Index'Min (I + 1, Sorted'Last))));

end Abacus.Sorting;
