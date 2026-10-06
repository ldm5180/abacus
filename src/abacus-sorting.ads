--  A stable sort proved to return a sorted permutation of its input,
--  ranks, and quantiles by the nearest rule and the linear one.  Ties
--  between equal values fall to a caller's key and then to the values'
--  places, so the order is the same however the data arrived.  The sort
--  is a merge sort, O(n log n), over data of up to Max_Length elements.

package Abacus.Sorting
  with SPARK_Mode
is

   --  The postconditions here are proved, and checking one at run time
   --  would cost more than the sort: whether an order is a permutation is
   --  a quantifier over every pair of places.  The preconditions, which
   --  compare bounds, are still checked.
   pragma Assertion_Policy (Post => Ignore);

   --  The longest data the sort takes.  Far past Max_N: a sort sums
   --  nothing, so the 128-bit bound that holds vectors to Max_N does not
   --  apply, and a table sorted by its columns may have millions of rows.
   Max_Length : constant := 2**30;

   --  A place in data to be sorted.
   subtype Place is Positive range 1 .. Max_Length;

   --  Values to be sorted, as many as Max_Length.  A Vector converts to
   --  one: Long_Vector (V).
   type Long_Vector is array (Place range <>) of Val;

   --  A permutation of places: Order (K) is the place, in the input, of
   --  the K-th element of the output.
   type Order_Array is array (Place range <>) of Place;

   --  Whether P maps its range onto itself one to one.
   function Is_Permutation (P : Order_Array) return Boolean
   is ((for all I in P'Range => P (I) in P'Range)
       and then (for all I in P'Range =>
                   (for all J in P'Range => (if I /= J then P (I) /= P (J)))));

   --  The total order the sort follows: by value, then by key, then by
   --  place.  No two places are equal, so no two elements tie.
   function Precedes (Values, Keys : Long_Vector; A, B : Place) return Boolean
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
     (Values, Keys : Long_Vector; Order : Order_Array) return Boolean
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

   function Is_Sorted (V : Long_Vector) return Boolean
   is (for all K in V'Range => (if K < V'Last then V (K) <= V (K + 1)));

   --  The order that sorts Values, ties by Keys then by place.  The merge
   --  needs a second order as long as the first: Scratch, the caller's,
   --  so a long one can come from the heap.  What it holds afterwards is
   --  of no use.
   procedure Sort_Order
     (Values, Keys : Long_Vector; Order, Scratch : out Order_Array)
   with
     Pre  =>
       Keys'First = Values'First
       and then Keys'Last = Values'Last
       and then Order'First = Values'First
       and then Order'Last = Values'Last
       and then Scratch'First = Values'First
       and then Scratch'Last = Values'Last,
     Post => Is_Permutation (Order) and then Sorted_By (Values, Keys, Order);

   --  The same, its scratch on the stack: for data short enough to keep
   --  there.
   procedure Sort_Order (Values, Keys : Long_Vector; Order : out Order_Array)
   with
     Pre  =>
       Keys'First = Values'First
       and then Keys'Last = Values'Last
       and then Order'First = Values'First
       and then Order'Last = Values'Last,
     Post => Is_Permutation (Order) and then Sorted_By (Values, Keys, Order);

   --  Values sorted in place, and the permutation that took them there.
   --  A copy of the values and the merge's scratch are on the stack.
   procedure Sort (Values : in out Long_Vector; Order : out Order_Array)
   with
     Pre  => Order'First = Values'First and then Order'Last = Values'Last,
     Post =>
       Is_Permutation (Order)
       and then Is_Sorted (Values)
       and then (for all K in Values'Range =>
                   Values (K) = Values'Old (Order (K)));

   --  Ranks (I) is the place of element I in the order Sort_Order gives:
   --  1 for the least.  Scratch is the caller's, as for Sort_Order.
   procedure Rank
     (Values, Keys : Long_Vector; Ranks, Scratch : out Order_Array)
   with
     Pre =>
       Keys'First = Values'First
       and then Keys'Last = Values'Last
       and then Ranks'First = Values'First
       and then Ranks'Last = Values'Last
       and then Scratch'First = Values'First
       and then Scratch'Last = Values'Last
       and then Values'First = 1;

   --  The same, its scratch on the stack.
   procedure Rank (Values, Keys : Long_Vector; Ranks : out Order_Array)
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
     (Sorted : Long_Vector; Q : Probability; How : Method) return Val
   with
     Pre  => Sorted'Length > 0 and then Is_Sorted (Sorted),
     Post =>
       (if How = Nearest
        then (for some I in Sorted'Range => Quantile'Result = Sorted (I))
        else
          (for some I in Sorted'Range =>
             Quantile'Result
             in Sorted (I) .. Sorted (Place'Min (I + 1, Sorted'Last))));

end Abacus.Sorting;
