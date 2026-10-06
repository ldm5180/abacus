--  A window of rows over several series, held as exact sums: the count,
--  each series' sum, and every pair's sum of products, at 128 bits.
--  Adding a row and removing one are exact, so a window slid any number
--  of times holds the very sums a fresh window over its rows would.

package Abacus.Stats.Rolling
  with SPARK_Mode
is

   type Wide_Vector is array (Index range <>) of Wide;
   type Wide_Matrix is array (Index range <>, Index range <>) of Wide;

   type Window (Series : Index) is record
      Rows  : Count := 0;
      Sums  : Wide_Vector (1 .. Series);
      Cross : Wide_Matrix (1 .. Series, 1 .. Series);
   end record;

   function Empty (Series : Index) return Window
   is ((Series => Series,
        Rows   => 0,
        Sums   => [others => 0],
        Cross  => [others => [others => 0]]));

   --  A row's entries are data, one per series.
   function Is_Row (W : Window; Row : Vector) return Boolean
   is (Row'First = 1 and then Row'Last = W.Series and then Is_Data (Row));

   --  The bounds a window of Rows rows keeps: each sum within Rows data,
   --  each sum of products within Rows products of data.
   function Bounded (W : Window) return Boolean
   is ((for all I in 1 .. W.Series =>
          W.Sums (I)
          in -(Wide (W.Rows) * Datum_Bound) .. Wide (W.Rows) * Datum_Bound)
       and then (for all I in 1 .. W.Series =>
                   (for all J in 1 .. W.Series =>
                      W.Cross (I, J)
                      in -(Wide (W.Rows) * Datum_Bound * Datum_Bound)
                       .. Wide (W.Rows) * Datum_Bound * Datum_Bound)));

   procedure Add_Row (W : in out Window; Row : Vector)
   with
     Pre  => Bounded (W) and then W.Rows < Max_N and then Is_Row (W, Row),
     Post => Bounded (W) and then W.Rows = W.Rows'Old + 1;

   --  Row taken out of the window.  A row that cannot have been in it --
   --  the window is empty, or a sum would leave the bounds of one row
   --  fewer -- clears Ok and leaves the window as it was.
   procedure Remove_Row (W : in out Window; Row : Vector; Ok : out Boolean)
   with
     Pre  => Bounded (W) and then Is_Row (W, Row),
     Post =>
       Bounded (W)
       and then (if Ok then W.Rows = W.Rows'Old - 1 else W = W'Old);

   --  The covariance of series I and J over the window's rows.
   function Covariance
     (W : Window; I, J : Index; Kind : Divisor_Kind) return Val
   with
     Pre =>
       Bounded (W)
       and then W.Rows >= Least (Kind)
       and then I <= W.Series
       and then J <= W.Series;

   function Variance (W : Window; I : Index; Kind : Divisor_Kind) return Val
   is (Covariance (W, I, I, Kind))
   with
     Pre => Bounded (W) and then W.Rows >= Least (Kind) and then I <= W.Series;

end Abacus.Stats.Rolling;
