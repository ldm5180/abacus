with Abacus.Arith;    use Abacus.Arith;
with Abacus.Matrices; use Abacus.Matrices;
with Abacus.Qp.Cones; use Abacus.Qp.Cones;
with Abacus.Vectors;

package body Abacus.Qp.Certificate
  with SPARK_Mode
is

   function Larger (A, B : Wide) return Wide
   is (if B > A then B else A);

   function Primal_Residual (Pr : Problem; St : State) return Wide is
      M : Wide := 0;
   begin
      for I in 1 .. Pr.N loop
         M := Larger (M, Outside (Wide (St.X (I)), Pr.Lo (I), Pr.Hi (I)));
         pragma Loop_Invariant (M in 0 .. 2 * Grid_Bound);
      end loop;
      for R in 1 .. Pr.K loop
         if not In_Cone (Pr, R) then
            M :=
              Larger
                (M,
                 Outside (Row_Of (Pr, R, St.X), Pr.Row_Lo (R), Pr.Row_Hi (R)));
         end if;
         pragma Loop_Invariant (M in 0 .. 2 * Grid_Bound);
      end loop;
      return M;
   end Primal_Residual;

   --  The cones' rows of E x less their vertex into V, zero elsewhere; Ok
   --  is False when one is not a value.
   procedure Cone_Rows
     (Pr : Problem; X : Vector; V : out Vector; Ok : out Boolean)
   with
     Pre =>
       X'First = 1
       and then X'Last = Pr.N
       and then V'First = 1
       and then V'Last = Pr.K
   is
   begin
      V := [others => 0];
      Ok := True;
      for R in 1 .. Pr.K loop
         if In_Cone (Pr, R) then
            Store (Row_Of (Pr, R, X) - Wide (Pr.Row_Lo (R)), V (R), Ok);
         end if;
      end loop;
   end Cone_Rows;

   --  The largest Excess or Polar_Excess of V over the problem's cones.
   function Worst_Cone (Pr : Problem; V : Vector; Polar : Boolean) return Wide
   with
     Pre  => V'First = 1 and then V'Last = Pr.K,
     Post => Worst_Cone'Result in 0 .. Beyond
   is
      M : Wide := 0;
   begin
      for R in 1 .. Pr.K loop
         if Starts_Cone (Pr, R) then
            M :=
              Larger
                (M,
                 (if Polar
                  then Polar_Excess (V, R, Cone_Last (Pr, R))
                  else Excess (V, R, Cone_Last (Pr, R))));
         end if;
         pragma Loop_Invariant (M in 0 .. Beyond);
      end loop;
      return M;
   end Worst_Cone;

   function Cone_Residual (Pr : Problem; St : State) return Wide is
      V  : Vector (1 .. Pr.K);
      Ok : Boolean;
   begin
      Cone_Rows (Pr, St.X, V, Ok);
      return (if Ok then Worst_Cone (Pr, V, Polar => False) else Beyond);
   end Cone_Residual;

   function Dual_Cone_Residual (Pr : Problem; St : State) return Wide
   is (Worst_Cone (Pr, St.Y_Row, Polar => True));

   --  Entry I of P x + Q + y + E'y_row.
   function Gradient (Pr : Problem; St : State; I : Index) return Wide
   is (Round_Shift (Row_Vector_Dot (Pr.P, I, St.X, 1, Pr.N))
       + Wide (Pr.Q (I))
       + Wide (St.Y (I))
       + Round_Shift (Column_Vector_Dot (Pr.E, I, St.Y_Row)))
   with Pre => Fits_State (Pr, St) and then I <= Pr.N;

   function Dual_Residual (Pr : Problem; St : State) return Wide is
      M : Wide := 0;
   begin
      for I in 1 .. Pr.N loop
         M := Larger (M, Magnitude (Gradient (Pr, St, I)));
         pragma Loop_Invariant (M >= 0);
      end loop;
      return M;
   end Dual_Residual;

   --  A slack held to 2**60, past which its term is large whatever the
   --  multiplier, so a product with a value stays inside 128 bits.
   Slack_Bound : constant := 2**60;

   function Clamp_Slack (W : Wide) return Wide
   is (Wide'Max (-Slack_Bound, Wide'Min (W, Slack_Bound)));

   --  A multiplier Y times the slack of the bound it holds, for a row at
   --  A with bounds Lo and Hi.
   function Slack_Term (Y : Val; A : Grid; Lo, Hi : Val) return Wide
   is (if Y > 0
       then
         (if Hi = No_Upper
          then Wide (Y)
          else
            Magnitude (Round_Shift (Wide (Y) * Clamp_Slack (Wide (Hi) - A))))
       elsif Y < 0
       then
         (if Lo = No_Lower
          then -Wide (Y)
          else
            Magnitude (Round_Shift (Wide (Y) * Clamp_Slack (A - Wide (Lo)))))
       else 0)
   with Post => Slack_Term'Result >= 0;

   --  The largest magnitude of a cone's multipliers' inner product with
   --  its rows of E x less the vertex; Beyond when a row is not a value.
   function Cone_Gap (Pr : Problem; St : State) return Wide
   with Pre => Fits_State (Pr, St), Post => Cone_Gap'Result >= 0
   is
      V    : Vector (1 .. Pr.K);
      Ok   : Boolean;
      M    : Wide := 0;
      Last : Index;
   begin
      Cone_Rows (Pr, St.X, V, Ok);
      if not Ok then
         return Beyond;
      end if;
      for R in 1 .. Pr.K loop
         if Starts_Cone (Pr, R) then
            Last := Cone_Last (Pr, R);
            M :=
              Larger
                (M,
                 Magnitude
                   (Round_Shift
                      (Vectors.Dot_Exact
                         (St.Y_Row (R .. Last), V (R .. Last)))));
         end if;
         pragma Loop_Invariant (M >= 0);
      end loop;
      return M;
   end Cone_Gap;

   function Complementarity (Pr : Problem; St : State) return Wide is
      M : Wide := 0;
   begin
      for I in 1 .. Pr.N loop
         M :=
           Larger
             (M, Slack_Term (St.Y (I), Wide (St.X (I)), Pr.Lo (I), Pr.Hi (I)));
         pragma Loop_Invariant (M >= 0);
      end loop;
      for R in 1 .. Pr.K loop
         if not In_Cone (Pr, R) then
            M :=
              Larger
                (M,
                 Slack_Term
                   (St.Y_Row (R),
                    Row_Of (Pr, R, St.X),
                    Pr.Row_Lo (R),
                    Pr.Row_Hi (R)));
         end if;
         pragma Loop_Invariant (M >= 0);
      end loop;
      return Larger (M, Cone_Gap (Pr, St));
   end Complementarity;

   ---------------------------------------------------------------------
   --  Infeasibility.
   ---------------------------------------------------------------------

   --  D = A - B entry by entry; Ok is False when a difference is not a
   --  value.
   procedure Delta_Of (A, B : Vector; D : out Vector; Ok : out Boolean)
   with
     Pre =>
       B'First = A'First
       and then B'Last = A'Last
       and then D'First = A'First
       and then D'Last = A'Last
   is
   begin
      D := [others => 0];
      Ok := True;
      for I in A'Range loop
         Store (Wide (A (I)) - Wide (B (I)), D (I), Ok);
      end loop;
   end Delta_Of;

   --  D projected onto the polar of the recession cone of [Lo, Hi], as
   --  OSQP does: a dual may not rise toward an open upper bound nor fall
   --  toward an open lower one, so that part of its change is dropped.
   procedure Project (D : in out Vector; Lo, Hi : Vector)
   with
     Pre =>
       Lo'First = D'First
       and then Lo'Last = D'Last
       and then Hi'First = D'First
       and then Hi'Last = D'Last
   is
   begin
      for I in D'Range loop
         if Hi (I) = No_Upper then
            D (I) := Val'Min (D (I), 0);
         end if;
         if Lo (I) = No_Lower then
            D (I) := Val'Max (D (I), 0);
         end if;
      end loop;
   end Project;

   --  The bounds' support of a change D in a row bounded by Lo and Hi:
   --  Hi D where D rises, Lo D where it falls.  Open is True when the
   --  bound D moves toward is open, so the support is unbounded.
   type Support is record
      Value : Wide;
      Open  : Boolean;
   end record;

   --  The bound on one term of the support: a rounded product of values.
   Support_Bound : constant := Arith.Shifted_Bound;

   function Support_Of (D, Lo, Hi : Val) return Support
   is (if D > 0
       then (Product_Of (Hi, D), Hi = No_Upper)
       elsif D < 0
       then (Product_Of (Lo, D), Lo = No_Lower)
       else (0, False))
   with Post => Support_Of'Result.Value in -Support_Bound .. Support_Bound;

   --  The support of the duals' change over the box and the rows, and
   --  whether any of it is open.
   function Total_Support (Pr : Problem; Dy, Dy_Row : Vector) return Support
   with
     Pre =>
       Dy'First = 1
       and then Dy'Last = Pr.N
       and then Dy_Row'First = 1
       and then Dy_Row'Last = Pr.K
   is
      Total : Support := (0, False);
      Term  : Support;
   begin
      for I in 1 .. Pr.N loop
         Term := Support_Of (Dy (I), Pr.Lo (I), Pr.Hi (I));
         Total := (Total.Value + Term.Value, Total.Open or else Term.Open);
         pragma
           Loop_Invariant
             (Total.Value
              in -(Wide (I) * Support_Bound) .. Wide (I) * Support_Bound);
      end loop;
      for R in 1 .. Pr.K loop
         Term := Support_Of (Dy_Row (R), Pr.Row_Lo (R), Pr.Row_Hi (R));
         Total := (Total.Value + Term.Value, Total.Open or else Term.Open);
         pragma
           Loop_Invariant
             (Total.Value
              in -(Wide (Pr.N + R) * Support_Bound)
               .. Wide (Pr.N + R) * Support_Bound);
      end loop;
      return Total;
   end Total_Support;

   --  The largest entry of A'dy = dy + E'dy_row.
   function Transposed_Change (Pr : Problem; Dy, Dy_Row : Vector) return Wide
   with
     Pre =>
       Dy'First = 1
       and then Dy'Last = Pr.N
       and then Dy_Row'First = 1
       and then Dy_Row'Last = Pr.K
   is
      M : Wide := 0;
   begin
      for I in 1 .. Pr.N loop
         M :=
           Larger
             (M,
              Magnitude
                (Wide (Dy (I))
                 + Round_Shift (Column_Vector_Dot (Pr.E, I, Dy_Row))));
      end loop;
      return M;
   end Transposed_Change;

   function Infeasible
     (Pr : Problem; St, Last : State; Ratio : Natural) return Boolean
   is
      Dy     : Vector (1 .. Pr.N);
      Dy_Row : Vector (1 .. Pr.K);
      Ok_Box : Boolean;
      Ok_Row : Boolean;
      Norm   : Wide;
      Total  : Support;
   begin
      Delta_Of (St.Y, Last.Y, Dy, Ok_Box);
      Delta_Of (St.Y_Row, Last.Y_Row, Dy_Row, Ok_Row);
      Project (Dy, Pr.Lo, Pr.Hi);
      Project (Dy_Row, Pr.Row_Lo, Pr.Row_Hi);
      Norm :=
        Larger
          (Wide (Vectors.Norm_Inf (Dy)), Wide (Vectors.Norm_Inf (Dy_Row)));
      if not (Ok_Box and then Ok_Row) or else Norm < Least_Change then
         return False;
      end if;
      Total := Total_Support (Pr, Dy, Dy_Row);
      return
        not Total.Open
        and then Transposed_Change (Pr, Dy, Dy_Row)
                 <= Norm / Powers_Of_Two (Ratio)
        and then Total.Value < -(Norm / Powers_Of_Two (Ratio));
   end Infeasible;

   ---------------------------------------------------------------------
   --  Unboundedness.
   ---------------------------------------------------------------------

   --  Whether a row's change A keeps to the recession cone of [Lo, Hi]
   --  within Limit: it may rise only toward an open upper bound and
   --  fall only toward an open lower one.
   subtype Limit_Value is Wide range 0 .. 2 * Val_Bound;

   function Recedes
     (A : Grid; Lo, Hi : Val; Limit : Limit_Value) return Boolean
   is ((Hi = No_Upper or else A <= Limit)
       and then (Lo = No_Lower or else A >= -Limit));

   --  Whether P dx, and every bounded row of dx, are within Limit.
   function Within_Cone
     (Pr : Problem; Dx : Vector; Limit : Limit_Value) return Boolean
   with Pre => Dx'First = 1 and then Dx'Last = Pr.N
   is
   begin
      for I in 1 .. Pr.N loop
         if Magnitude (Round_Shift (Row_Vector_Dot (Pr.P, I, Dx, 1, Pr.N)))
           > Limit
           or else not Recedes (Wide (Dx (I)), Pr.Lo (I), Pr.Hi (I), Limit)
         then
            return False;
         end if;
      end loop;
      for R in 1 .. Pr.K loop
         if not Recedes
                  (Row_Of (Pr, R, Dx), Pr.Row_Lo (R), Pr.Row_Hi (R), Limit)
         then
            return False;
         end if;
      end loop;
      return True;
   end Within_Cone;

   function Unbounded
     (Pr : Problem; St, Last : State; Ratio : Natural) return Boolean
   is
      Dx    : Vector (1 .. Pr.N);
      Ok    : Boolean;
      Norm  : Wide;
      Limit : Limit_Value;
   begin
      Delta_Of (St.X, Last.X, Dx, Ok);
      Norm := Wide (Vectors.Norm_Inf (Dx));
      if not Ok or else Norm < Least_Change then
         return False;
      end if;
      Limit := Norm / Powers_Of_Two (Ratio);
      return
        Vectors.Dot (Pr.Q, Dx) < -Limit and then Within_Cone (Pr, Dx, Limit);
   end Unbounded;

end Abacus.Qp.Certificate;
