with Abacus.Arith;

package body Abacus.Stats.Rolling
  with SPARK_Mode
is

   Product_Bound : constant := Datum_Bound * Datum_Bound;

   function Term (A, B : Datum) return Wide
   is (Wide (A) * Wide (B))
   with Post => Term'Result in -Product_Bound .. Product_Bound;

   --  Sign one adds a row, minus one takes it out.
   type Direction is range -1 .. 1;

   --  The sums with Row added (D = 1) or taken out (D = -1), each entry
   --  changed exactly once.
   procedure Apply (W : in out Window; Row : Vector; D : Direction)
   with
     Pre  => Is_Row (W, Row) and then Bounded (W),
     Post =>
       W.Rows = W.Rows'Old
       and then (for all K in 1 .. W.Series =>
                   W.Sums (K) = W.Sums'Old (K) + Wide (D) * Wide (Row (K)))
       and then (for all K in 1 .. W.Series =>
                   (for all L in 1 .. W.Series =>
                      W.Cross (K, L)
                      = W.Cross'Old (K, L)
                        + Wide (D) * Term (Row (K), Row (L))))
   is
   begin
      for I in 1 .. W.Series loop
         W.Sums (I) := W.Sums (I) + Wide (D) * Wide (Row (I));
         for J in 1 .. W.Series loop
            W.Cross (I, J) :=
              W.Cross (I, J) + Wide (D) * Term (Row (I), Row (J));
            pragma
              Loop_Invariant
                (for all K in 1 .. W.Series =>
                   (for all L in 1 .. W.Series =>
                      W.Cross (K, L)
                      = W.Cross'Loop_Entry (K, L)
                        + (if K = I and then L <= J
                           then Wide (D) * Term (Row (K), Row (L))
                           else 0)));
         end loop;
         pragma
           Loop_Invariant
             (for all K in 1 .. W.Series =>
                W.Sums (K)
                = W.Sums'Loop_Entry (K)
                  + (if K <= I then Wide (D) * Wide (Row (K)) else 0));
         pragma
           Loop_Invariant
             (for all K in 1 .. W.Series =>
                (for all L in 1 .. W.Series =>
                   W.Cross (K, L)
                   = W.Cross'Loop_Entry (K, L)
                     + (if K <= I
                        then Wide (D) * Term (Row (K), Row (L))
                        else 0)));
      end loop;
   end Apply;

   procedure Add_Row (W : in out Window; Row : Vector) is
   begin
      Apply (W, Row, 1);
      W.Rows := W.Rows + 1;
   end Add_Row;

   --  Whether taking Row out leaves every sum within the bounds of a
   --  window of one row fewer.
   function Removable (W : Window; Row : Vector) return Boolean
   is (W.Rows > 0
       and then (for all I in 1 .. W.Series =>
                   W.Sums (I) - Wide (Row (I))
                   in -(Wide (W.Rows - 1) * Datum_Bound)
                    .. Wide (W.Rows - 1) * Datum_Bound)
       and then (for all I in 1 .. W.Series =>
                   (for all J in 1 .. W.Series =>
                      W.Cross (I, J) - Term (Row (I), Row (J))
                      in -(Wide (W.Rows - 1) * Product_Bound)
                       .. Wide (W.Rows - 1) * Product_Bound)))
   with Pre => Bounded (W) and then Is_Row (W, Row);

   procedure Remove_Row (W : in out Window; Row : Vector; Ok : out Boolean) is
   begin
      Ok := Removable (W, Row);
      if not Ok then
         return;
      end if;
      Apply (W, Row, -1);
      W.Rows := W.Rows - 1;
   end Remove_Row;

   --  (n S_ij - S_i S_j) / (n (n - d)), at scale One * One before the
   --  one rounding, d one for a sample and zero for a population.
   function Covariance
     (W : Window; I, J : Index; Kind : Divisor_Kind) return Val
   is
      N     : constant Wide := Wide (W.Rows);
      Numer : constant Wide := N * W.Cross (I, J) - W.Sums (I) * W.Sums (J);
      Denom : constant Wide := N * (if Kind = Sample then N - 1 else N) * One;
   begin
      return
        Val
          (Wide'Max
             (Wide (Val'First),
              Wide'Min (Arith.Div_Round (Numer, Denom), Wide (Val'Last))));
   end Covariance;

end Abacus.Stats.Rolling;
