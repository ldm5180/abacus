with Abacus.Arith;

package body Abacus.Sorting
  with SPARK_Mode
is

   --  Every contract in this body is proved, and checking them at run
   --  time would make the sort quadratic: the invariants quantify over
   --  every pair of places.  The ghost witnesses the proof follows go
   --  with them.
   pragma Assertion_Policy (Ignore);

   --  Whether Order lists places First .. Last of Values in the sort's
   --  order, pair by adjacent pair.
   function Sorted_Between
     (Values, Keys : Long_Vector; Order : Order_Array; First, Last : Natural)
      return Boolean
   is (for all K in First .. Last - 1 =>
         Precedes (Values, Keys, Order (K), Order (K + 1)))
   with
     Pre =>
       Keys'First = Values'First
       and then Keys'Last = Values'Last
       and then (if First <= Last
                 then
                   First >= Order'First
                   and then Last <= Order'Last
                   and then (for all K in First .. Last =>
                               Order (K) in Values'Range));

   --  Whether Keys and Order lie over the places of Values.
   function Over
     (Values, Keys : Long_Vector; Order : Order_Array) return Boolean
   is (Keys'First = Values'First
       and then Keys'Last = Values'Last
       and then Order'First = Values'First
       and then Order'Last = Values'Last);

   --  Places Lo .. Hi of an order, to be sorted as a whole.
   type Run is record
      Lo, Hi : Place;
   end record;

   --  The last place of a run's first half.
   function Half (R : Run) return Place
   is (R.Lo + (R.Hi - R.Lo) / 2)
   with Pre => R.Lo <= R.Hi;

   --  Whether R lies within the places of Order.
   function Within (R : Run; Order : Order_Array) return Boolean
   is (R.Lo <= R.Hi and then R.Lo >= Order'First and then R.Hi <= Order'Last);

   --  Whether Order holds no place twice within R.
   function Distinct (Order : Order_Array; R : Run) return Boolean
   is (for all I in R.Lo .. R.Hi =>
         (for all J in I + 1 .. R.Hi => Order (I) /= Order (J)))
   with Pre => R.Lo > R.Hi or else Within (R, Order);

   --  Whether every place Into holds within R is one From holds there.
   function Drawn_From (Into, From : Order_Array; R : Run) return Boolean
   is (for all K in R.Lo .. R.Hi =>
         (for some W in R.Lo .. R.Hi => Into (K) = From (W)))
   with Pre => Within (R, Into) and then Within (R, From);

   --  Whether Order and Before agree outside R.
   function Same_Outside (Order, Before : Order_Array; R : Run) return Boolean
   is (for all K in Order'Range =>
         (if K not in R.Lo .. R.Hi then Order (K) = Before (K)))
   with Pre => Before'First = Order'First and then Before'Last = Order'Last;

   --  The two halves of R in From, each sorted, merged into Into: the
   --  first half's place is taken while it precedes the second's, so
   --  the merge is stable.  Source, ghost, is where each came from.
   procedure Merge
     (Values, Keys : Long_Vector;
      From         : Order_Array;
      Into         : in out Order_Array;
      R            : Run)
   with
     Pre  =>
       Over (Values, Keys, From)
       and then Into'First = From'First
       and then Into'Last = From'Last
       and then Within (R, From)
       and then R.Lo < R.Hi
       and then (for all K in R.Lo .. R.Hi => From (K) in Values'Range)
       and then Distinct (From, R)
       and then Sorted_Between (Values, Keys, From, R.Lo, Half (R))
       and then Sorted_Between (Values, Keys, From, Half (R) + 1, R.Hi),
     Post =>
       (for all K in R.Lo .. R.Hi => Into (K) in Values'Range)
       and then Drawn_From (Into, From, R)
       and then Distinct (Into, R)
       and then Sorted_Between (Values, Keys, Into, R.Lo, R.Hi)
       and then Same_Outside (Into, Into'Old, R);

   procedure Merge
     (Values, Keys : Long_Vector;
      From         : Order_Array;
      Into         : in out Order_Array;
      R            : Run)
   is
      Mid    : constant Place := Half (R);
      I      : Positive := R.Lo;
      J      : Positive := Mid + 1;
      Source : Order_Array (R.Lo .. R.Hi) := [others => R.Lo]
      with Ghost;
   begin
      for K in R.Lo .. R.Hi loop
         if J > R.Hi
           or else (I <= Mid
                    and then Precedes (Values, Keys, From (I), From (J)))
         then
            Into (K) := From (I);
            Source (K) := I;
            I := I + 1;
         else
            Into (K) := From (J);
            Source (K) := J;
            J := J + 1;
         end if;
         pragma
           Assert (for all M in R.Lo .. K - 1 => Source (M) /= Source (K));
         pragma Assert (for all M in R.Lo .. K - 1 => Into (M) /= Into (K));
         pragma
           Assert
             (for all M in R.Lo .. K - 1 =>
                (for all N in M + 1 .. K - 1 => Into (M) /= Into (N)));
         pragma Loop_Invariant (I in R.Lo .. Mid + 1);
         pragma Loop_Invariant (J in Mid + 1 .. R.Hi + 1);
         pragma Loop_Invariant ((I - R.Lo) + (J - Mid - 1) = K - R.Lo + 1);
         pragma
           Loop_Invariant
             (for all M in R.Lo .. K =>
                Into (M) = From (Source (M))
                and then (Source (M) in R.Lo .. I - 1
                          or else Source (M) in Mid + 1 .. J - 1));
         pragma Loop_Invariant (Distinct (Into, (R.Lo, K)));
         pragma Loop_Invariant (Sorted_Between (Values, Keys, Into, R.Lo, K));
         pragma
           Loop_Invariant
             (if I <= Mid then Precedes (Values, Keys, Into (K), From (I)));
         pragma
           Loop_Invariant
             (if J <= R.Hi then Precedes (Values, Keys, Into (K), From (J)));
         pragma Loop_Invariant (Same_Outside (Into, Into'Loop_Entry, R));
      end loop;
   end Merge;

   --  Order within R replaced by Scratch's, a rearrangement of it.
   procedure Take_Back
     (Values, Keys : Long_Vector;
      Order        : in out Order_Array;
      Scratch      : Order_Array;
      R            : Run)
   with
     Pre  =>
       Over (Values, Keys, Order)
       and then Scratch'First = Order'First
       and then Scratch'Last = Order'Last
       and then Within (R, Order)
       and then Is_Permutation (Order)
       and then (for all K in R.Lo .. R.Hi => Scratch (K) in Values'Range)
       and then Drawn_From (Scratch, Order, R)
       and then Distinct (Scratch, R)
       and then Sorted_Between (Values, Keys, Scratch, R.Lo, R.Hi),
     Post =>
       Is_Permutation (Order)
       and then Sorted_Between (Values, Keys, Order, R.Lo, R.Hi)
       and then Same_Outside (Order, Order'Old, R)
   is
   begin
      Order (R.Lo .. R.Hi) := Scratch (R.Lo .. R.Hi);
   end Take_Back;

   --  Order within R sorted: each half sorted, then the two merged
   --  through Scratch unless they already meet in order.
   procedure Sort_Run
     (Values, Keys : Long_Vector; Order, Scratch : in out Order_Array; R : Run)
   with
     Pre                =>
       Over (Values, Keys, Order)
       and then Scratch'First = Order'First
       and then Scratch'Last = Order'Last
       and then Within (R, Order)
       and then Is_Permutation (Order),
     Post               =>
       Is_Permutation (Order)
       and then Sorted_Between (Values, Keys, Order, R.Lo, R.Hi)
       and then Same_Outside (Order, Order'Old, R),
     Subprogram_Variant => (Decreases => R.Hi - R.Lo)
   is
   begin
      if R.Lo < R.Hi then
         Sort_Run (Values, Keys, Order, Scratch, (R.Lo, Half (R)));
         Sort_Run (Values, Keys, Order, Scratch, (Half (R) + 1, R.Hi));
         if not Precedes (Values, Keys, Order (Half (R)), Order (Half (R) + 1))
         then
            Merge (Values, Keys, Order, Scratch, R);
            Take_Back (Values, Keys, Order, Scratch, R);
         end if;
      end if;
   end Sort_Run;

   procedure Sort_Order
     (Values, Keys : Long_Vector; Order, Scratch : out Order_Array) is
   begin
      --  Not [for K in Order'Range => K], nor an aggregate that names
      --  Order: GNAT builds either on the stack, which a long order
      --  overflows.
      Order := [others => Place'First];
      for K in Order'Range loop
         Order (K) := K;
         pragma
           Loop_Invariant (for all M in Order'First .. K => Order (M) = M);
      end loop;
      Scratch := Order;
      if Order'Length > 0 then
         Sort_Run (Values, Keys, Order, Scratch, (Order'First, Order'Last));
      end if;
   end Sort_Order;

   procedure Sort_Order (Values, Keys : Long_Vector; Order : out Order_Array)
   is
      Scratch : Order_Array (Values'Range);
      pragma
        Warnings
          (GNATprove,
           Off,
           """Scratch"" is set by ""Sort_Order"" but not used after the call",
           Reason => "the merge's scratch is spent once the order is made");
   begin
      Sort_Order (Values, Keys, Order, Scratch);
   end Sort_Order;

   procedure Sort (Values : in out Long_Vector; Order : out Order_Array) is
      Before : constant Long_Vector := Values;
   begin
      --  The values are their own keys: a tie on value is a tie on key,
      --  so the order is by value, then place.
      Sort_Order (Before, Before, Order);
      for K in Values'Range loop
         Values (K) := Before (Order (K));
         pragma
           Loop_Invariant
             (for all L in Values'First .. K =>
                Values (L) = Before (Order (L)));
      end loop;
   end Sort;

   procedure Rank
     (Values, Keys : Long_Vector; Ranks, Scratch : out Order_Array) is
   begin
      Sort_Order (Values, Keys, Scratch, Ranks);
      for K in Scratch'Range loop
         Ranks (Scratch (K)) := K;
      end loop;
   end Rank;

   procedure Rank (Values, Keys : Long_Vector; Ranks : out Order_Array) is
      Scratch : Order_Array (Values'Range);
      pragma
        Warnings
          (GNATprove,
           Off,
           """Scratch"" is set by ""Rank"" but not used after the call",
           Reason => "the merge's scratch is spent once the ranks are made");
   begin
      Rank (Values, Keys, Ranks, Scratch);
   end Rank;

   --  Q (n - 1) for n elements, at scale One.
   function Position (Q : Probability; N : Positive) return Wide
   is (Wide (Q) * Wide (N - 1))
   with
     Pre  => N <= Max_Length,
     Post => Position'Result in 0 .. Wide (N - 1) * One;

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
     (Sorted : Long_Vector; Q : Probability; How : Method) return Val
   is
      H    : constant Wide := Position (Q, Sorted'Length);
      Near : constant Place :=
        Sorted'First + Natural (Arith.Div_Round (H, One));
      Low  : constant Place := Sorted'First + Natural (H / One);
   begin
      if How = Nearest or else Low = Sorted'Last then
         return Sorted (if How = Nearest then Near else Low);
      end if;
      return Between (Sorted (Low), Sorted (Low + 1), H mod One);
   end Quantile;

end Abacus.Sorting;
