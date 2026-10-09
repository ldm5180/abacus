with Abacus.Arith;    use Abacus.Arith;
with Abacus.Qp.Cones;
with Abacus.Qp.Picks; use Abacus.Qp.Picks;
with Abacus.Qp.Held;  use Abacus.Qp.Held;
with Abacus.Vectors;

package body Abacus.Qp.Crossover
  with SPARK_Mode
is

   --  A rate under it, 2**-24 of a value, is no pivot: the edge lies
   --  nearly along the bound.
   Rate_Floor : constant := 2**(Frac - 24);

   --  How far inside its sign a shifted multiplier is set.
   Shift_Margin : constant := 2**16;

   --  The largest rate a ratio is taken over: past it the edge is held to
   --  it, which only makes its step shorter.
   Rate_Bound : constant := 2**90;

   --  |V|.
   function Size_Of (V : Wide) return Wide
   is (if V < 0 then -V else V)
   with Pre => V > Wide'First;

   --  W held to -B .. B.
   function Held_To (W : Wide; B : Wide) return Wide
   is (Wide'Max (-B, Wide'Min (B, W)))
   with Pre => B >= 0, Post => Held_To'Result in -B .. B;

   --  Whether In_Row and Place name a row or a variable of Pr.
   function Names
     (Pr : Problem; In_Row : Boolean; Place : Index) return Boolean
   is (if In_Row then Place <= Pr.K else Place <= Pr.N);

   --  The direction a held side moves off its bound: up from a lower,
   --  down from an upper.
   function Off (S : Side) return Wide
   is (if S = At_Upper then -1 else 1);

   ---------------------------------------------------------------------
   --  A basis.
   ---------------------------------------------------------------------

   --  The bound of [Lo, Hi] nearest X, Free when neither is finite.
   function Nearest_Side (X, Lo, Hi : Val) return Side
   is (if Lo /= No_Lower
         and then (Hi = No_Upper
                   or else Wide (X) - Wide (Lo) <= Wide (Hi) - Wide (X))
       then At_Lower
       elsif Hi /= No_Upper
       then At_Upper
       else Free);

   --  The held variable, not fixed, with the largest entry in row R: one
   --  to free so the row is supported; zero for none.
   function Support (Pr : Problem; Work : Workspace; R : Index) return Count
   with Pre => Fits_Work (Pr, Work) and then R <= Pr.K
   is
      Best : Count := 0;
      Most : Wide := 0;
   begin
      for J in 1 .. Pr.N loop
         if not Is_Free (Work, J)
           and then Pr.Lo (J) /= Pr.Hi (J)
           and then Size_Of (Wide (Pr.E (R, J))) > Most
         then
            Most := Size_Of (Wide (Pr.E (R, J)));
            Best := J;
         end if;
         pragma Loop_Invariant (Best <= J);
      end loop;
      return Best;
   end Support;

   --  A dependent held row released when it is an inequality, given a
   --  variable to rest on when it is an equality.
   procedure Mend_Row
     (Pr : Problem; Work : in out Workspace; R : Index; Ok : in out Boolean)
   with Pre => Fits_Work (Pr, Work) and then R <= Pr.K
   is
      J : constant Count := Support (Pr, Work, R);
   begin
      if Pr.Row_Lo (R) /= Pr.Row_Hi (R) then
         Work.Row_Side (R) := Free;
      elsif J in 1 .. Pr.N then
         Work.Box_Side (J) := Free;
      else
         Ok := False;
      end if;
   end Mend_Row;

   --  One dependence mended: a dependent held row as Mend_Row does, a
   --  dependent free column held at the bound St lies nearest.
   procedure Mend
     (Pr    : Problem;
      St    : State;
      Work  : in out Workspace;
      Found : Dependence;
      Ok    : in out Boolean)
   with Pre => Packed (Pr, Work) and then Fits_State (Pr, St)
   is
      I : Index;
   begin
      if Found.Row in 1 .. Work.Row_Count then
         Mend_Row (Pr, Work, Work.Row_At (Found.Row), Ok);
      elsif Found.Column in 1 .. Work.Free_Count then
         I := Work.Free_At (Found.Column);
         Work.Box_Side (I) := Nearest_Side (St.X (I), Pr.Lo (I), Pr.Hi (I));
         Ok := Ok and then Work.Box_Side (I) /= Free;
      end if;
   end Mend;

   --  The free variable St lies nearest a bound of: one to hold when
   --  more variables are free than rows held; zero for none with a bound.
   function Nearest_Free
     (Pr : Problem; St : State; Work : Workspace) return Count
   with Pre => Fits_Work (Pr, Work) and then Fits_State (Pr, St)
   is
      Best : Count := 0;
      Gap  : Wide := Wide'Last;
      D    : Wide;
   begin
      for I in 1 .. Pr.N loop
         if Is_Free (Work, I)
           and then Nearest_Side (St.X (I), Pr.Lo (I), Pr.Hi (I)) /= Free
         then
            D :=
              Size_Of
                (Wide (St.X (I))
                 - Wide
                     (Bound_Of
                        (Nearest_Side (St.X (I), Pr.Lo (I), Pr.Hi (I)),
                         Pr.Lo (I),
                         Pr.Hi (I))));
            if D < Gap then
               Gap := D;
               Best := I;
            end if;
         end if;
         pragma Loop_Invariant (Best <= I);
      end loop;
      return Best;
   end Nearest_Free;

   --  A held set with no dependence found but not square, squared by one:
   --  a free variable held at its nearest bound when more are free, a
   --  held inequality row released when more rows are held.
   procedure Square
     (Pr : Problem; St : State; Work : in out Workspace; Ok : in out Boolean)
   with Pre => Fits_Work (Pr, Work) and then Fits_State (Pr, St)
   is
      I : constant Count := Nearest_Free (Pr, St, Work);
   begin
      if Work.Free_Count > Work.Row_Count and then I in 1 .. Pr.N then
         Work.Box_Side (I) := Nearest_Side (St.X (I), Pr.Lo (I), Pr.Hi (I));
      elsif Work.Row_Count > Work.Free_Count then
         Ok := False;
         for R in 1 .. Pr.K loop
            if Is_Held_Row (Work, R) and then Pr.Row_Lo (R) /= Pr.Row_Hi (R)
            then
               Work.Row_Side (R) := Free;
               Ok := True;
               exit;
            end if;
         end loop;
      else
         Ok := False;
      end if;
   end Square;

   --  Work's held set made a basis, square, its held rows independent
   --  over its free columns; Ok is False when it cannot be.
   procedure Make_Basis
     (Pr : Problem; St : State; Work : in out Workspace; Ok : out Boolean)
   with Pre => Fits_Work (Pr, Work) and then Fits_State (Pr, St)
   is
      Found : Dependence;
   begin
      for Round in 1 .. Pr.N + Pr.K + 1 loop
         Find_Dependence (Pr, Work, Found, Ok);
         exit when not Ok;
         if Found = (0, 0) and then Work.Row_Count = Work.Free_Count then
            return;
         elsif Found = (0, 0) then
            Square (Pr, St, Work, Ok);
         else
            Mend (Pr, St, Work, Found, Ok);
         end if;
         exit when not Ok;
         pragma Loop_Invariant (Fits_Work (Pr, Work));
      end loop;
      Ok := False;
   end Make_Basis;

   ---------------------------------------------------------------------
   --  The cost shifted, so each held multiplier has its sign.
   ---------------------------------------------------------------------

   --  The multiplier a shift gives a held side: just inside its sign.
   function Wanted (S : Side) return Val
   is (if S = At_Upper then Shift_Margin else -Shift_Margin);

   --  Cost shifted by C times row R, which moves R's multiplier by -C.
   procedure Add_Row
     (Pr   : Problem;
      R    : Index;
      C    : Val;
      Cost : in out Vector;
      Ok   : in out Boolean)
   with Pre => R <= Pr.K and then Cost'First = 1 and then Cost'Last = Pr.N
   is
   begin
      for J in 1 .. Pr.N loop
         Store (Wide (Cost (J)) + Product_Of (C, Pr.E (R, J)), Cost (J), Ok);
      end loop;
   end Add_Row;

   --  Cost shifted so each held row's multiplier in Cand has its sign.
   procedure Shift_Rows
     (Pr   : Problem;
      Work : Workspace;
      Cand : State;
      Cost : in out Vector;
      Ok   : in out Boolean)
   with
     Pre =>
       Fits_Work (Pr, Work)
       and then Fits_State (Pr, Cand)
       and then Cost'First = 1
       and then Cost'Last = Pr.N
   is
      C : Val := 0;
   begin
      for R in 1 .. Pr.K loop
         if Wrong_Push
              (Work.Row_Side (R), Cand.Y_Row (R), Pr.Row_Lo (R), Pr.Row_Hi (R))
           > 0
         then
            Store
              (Wide (Cand.Y_Row (R)) - Wide (Wanted (Work.Row_Side (R))),
               C,
               Ok);
            Add_Row (Pr, R, C, Cost, Ok);
         end if;
      end loop;
   end Shift_Rows;

   --  Cost shifted so each held variable's multiplier in Cand has its
   --  sign: its own cost moves its multiplier one for one.
   procedure Shift_Boxes
     (Pr   : Problem;
      Work : Workspace;
      Cand : State;
      Cost : in out Vector;
      Ok   : in out Boolean)
   with
     Pre =>
       Fits_Work (Pr, Work)
       and then Fits_State (Pr, Cand)
       and then Cost'First = 1
       and then Cost'Last = Pr.N
   is
   begin
      for J in 1 .. Pr.N loop
         if Wrong_Push (Work.Box_Side (J), Cand.Y (J), Pr.Lo (J), Pr.Hi (J))
           > 0
         then
            Store
              (Wide (Cost (J))
               + Wide (Cand.Y (J))
               - Wide (Wanted (Work.Box_Side (J))),
               Cost (J),
               Ok);
         end if;
      end loop;
   end Shift_Boxes;

   --  What a walk holds: the vertex last solved, the shifted cost, and
   --  whether the walk is dual (to feasibility) or primal (to the
   --  optimum), Bland's rule is due, it has ended, and it found a vertex.
   type Phase is (Dual, Primal);

   type Walk
     (N : Index;
      K : Count)
   is record
      Cand  : State (N, K);
      Cost  : Vector (1 .. N);
      Now   : Phase;
      Bland : Boolean;
      Ended : Boolean;
      Ok    : Boolean;
   end record;

   function Fits_Walk (Pr : Problem; W : Walk) return Boolean
   is (W.N = Pr.N and then W.K = Pr.K);

   --  W's cost shifted from the problem's for Work's held set, from St.
   procedure Shift
     (Pr : Problem; Work : in out Workspace; St : State; W : in out Walk)
   with
     Pre =>
       Fits_Work (Pr, Work)
       and then Fits_State (Pr, St)
       and then Fits_Walk (Pr, W)
   is
      Solved : Boolean;
   begin
      W.Cost := Pr.Q;
      W.Cand := St;
      Solve_Vertex (Pr, Pr.Q, Work, W.Cand, Solved);
      W.Ok := W.Ok and then Solved;
      Shift_Rows (Pr, Work, W.Cand, W.Cost, W.Ok);
      W.Cand := St;
      Solve_Vertex (Pr, W.Cost, Work, W.Cand, Solved);
      W.Ok := W.Ok and then Solved;
      Shift_Boxes (Pr, Work, W.Cand, W.Cost, W.Ok);
      W.Now := Dual;
   end Shift;

   ---------------------------------------------------------------------
   --  Ratios.
   ---------------------------------------------------------------------

   --  A ratio test's choice: whether one was found, its ratio, whether a
   --  row, which, and the side it is to take.
   type Choice is record
      Found  : Boolean := False;
      Ratio  : Wide := 0;
      In_Row : Boolean := False;
      Place  : Index := Index'First;
      To     : Side := Free;
   end record;

   --  C with the candidate when it is found and its ratio smaller: ties go
   --  to the earlier, which is Bland's rule among them.
   procedure Keep_Smaller (C : in out Choice; Candidate : Choice) is
   begin
      if Candidate.Found
        and then (not C.Found or else Candidate.Ratio < C.Ratio)
      then
         C := Candidate;
      end if;
   end Keep_Smaller;

   --  Distance over Rate as a value, both positive, the rate held to
   --  Rate_Bound.
   function Ratio_Of (Distance : Wide; Rate : Wide) return Wide
   is (Div_Round
         (Wide'Min (Distance, 2 * Val_Bound) * One,
          Wide'Max (1, Wide'Min (Rate, Rate_Bound))))
   with Pre => Distance >= 0 and then Rate > 0;

   ---------------------------------------------------------------------
   --  A dual pivot.
   ---------------------------------------------------------------------

   --  The leaving constraint's row over the free variables, packed: a
   --  free variable's unit, or a free row's entries.
   procedure Leaving_Row
     (Pr : Problem; Work : Workspace; Leave : Pick; C : out Vector)
   with
     Pre =>
       Packed (Pr, Work)
       and then C'First = 1
       and then C'Last = Pr.N
       and then (if Leave.In_Row then Leave.Place <= Pr.K)
   is
   begin
      C := [others => 0];
      for Q in 1 .. Work.Free_Count loop
         C (Q) :=
           (if Leave.In_Row
            then Pr.E (Leave.Place, Work.Free_At (Q))
            elsif Work.Free_At (Q) = Leave.Place
            then One
            else 0);
      end loop;
   end Leaving_Row;

   --  The sum over the held rows of W times column J of E, exact.
   function Held_Column_Dot
     (Pr : Problem; Work : Workspace; W : Vector; J : Index) return Wide
   with
     Pre  =>
       Packed (Pr, Work)
       and then W'First = 1
       and then W'Last = Pr.K
       and then J <= Pr.N,
     Post => Held_Column_Dot'Result in -Vectors.Dot_Bound .. Vectors.Dot_Bound
   is
      Sum : Wide := 0;
   begin
      for P in 1 .. Work.Row_Count loop
         Sum := Sum + Wide (W (P)) * Wide (Pr.E (Work.Row_At (P), J));
         pragma
           Loop_Invariant
             (Sum
              in -(Wide (P) * Vectors.Term_Bound)
               .. Wide (P) * Vectors.Term_Bound);
      end loop;
      return Sum;
   end Held_Column_Dot;

   --  How the leaving constraint moves as held variable J moves off its
   --  bound by one.
   function Box_Alpha
     (Pr : Problem; Work : Workspace; W : Vector; Leave : Pick; J : Index)
      return Wide
   is ((Wide (if Leave.In_Row then Pr.E (Leave.Place, J) else 0)
        - Round_Shift (Held_Column_Dot (Pr, Work, W, J)))
       * Off (Work.Box_Side (J)))
   with
     Pre =>
       Packed (Pr, Work)
       and then W'First = 1
       and then W'Last = Pr.K
       and then J <= Pr.N
       and then (if Leave.In_Row then Leave.Place <= Pr.K);

   --  The choice a held constraint offers a dual pivot: its multiplier
   --  over Alpha, when Alpha moves the leaving constraint toward its
   --  bound (up when it is below, Need 1; down when above, Need -1).
   function Dual_Offer
     (Alpha : Wide; Y : Val; Need : Wide; In_Row : Boolean; Place : Index)
      return Choice
   is (if Alpha * Need > Rate_Floor
       then
         (True,
          Ratio_Of (Size_Of (Wide (Y)), Alpha * Need),
          In_Row,
          Place,
          Free)
       else (others => <>))
   with
     Pre =>
       Need in -1 .. 1 and then Alpha in -(4 * Rate_Bound) .. 4 * Rate_Bound;

   --  The entering constraint of a dual pivot: of the held inequalities
   --  whose move takes the leaving one toward its bound, the one whose
   --  multiplier in Cand reaches zero first.
   function Dual_Entering
     (Pr : Problem; Work : Workspace; Cand : State; W : Vector; Leave : Pick)
      return Choice
   with
     Pre =>
       Packed (Pr, Work)
       and then Fits_State (Pr, Cand)
       and then W'First = 1
       and then W'Last = Pr.K
       and then (if Leave.In_Row then Leave.Place <= Pr.K)
   is
      Need : constant Wide := (if Leave.To = At_Lower then 1 else -1);
      C    : Choice;
   begin
      for J in 1 .. Pr.N loop
         if not Is_Free (Work, J) and then Pr.Lo (J) /= Pr.Hi (J) then
            Keep_Smaller
              (C,
               Dual_Offer
                 (Held_To (Box_Alpha (Pr, Work, W, Leave, J), 4 * Rate_Bound),
                  Cand.Y (J),
                  Need,
                  False,
                  J));
         end if;
      end loop;
      for P in 1 .. Work.Row_Count loop
         if Pr.Row_Lo (Work.Row_At (P)) /= Pr.Row_Hi (Work.Row_At (P)) then
            Keep_Smaller
              (C,
               Dual_Offer
                 (Wide (W (P)) * Off (Work.Row_Side (Work.Row_At (P))),
                  Cand.Y_Row (Work.Row_At (P)),
                  Need,
                  True,
                  Work.Row_At (P)));
         end if;
      end loop;
      return C;
   end Dual_Entering;

   --  Work's sides after a pivot: the entering constraint released, the
   --  leaving one held at the side it is to take.
   procedure Swap
     (Pr : Problem; Work : in out Workspace; Enter : Choice; Leave : Pick)
   with
     Pre =>
       Fits_Work (Pr, Work)
       and then Names (Pr, Enter.In_Row, Enter.Place)
       and then Names (Pr, Leave.In_Row, Leave.Place)
   is
   begin
      if Enter.In_Row then
         Work.Row_Side (Enter.Place) := Free;
      else
         Work.Box_Side (Enter.Place) := Free;
      end if;
      if Leave.In_Row then
         Work.Row_Side (Leave.Place) := Leave.To;
      else
         Work.Box_Side (Leave.Place) := Leave.To;
      end if;
   end Swap;

   --  One step of the dual walk: the vertex for the shifted cost; when it
   --  is feasible the walk turns primal, else the most violated free
   --  constraint leaves and the held one its row first frees enters.
   procedure Dual_Step
     (Pr   : Problem;
      S    : Settings;
      Work : in out Workspace;
      St   : State;
      W    : in out Walk)
   with
     Pre =>
       Fits_Work (Pr, Work)
       and then Fits_State (Pr, St)
       and then Fits_Walk (Pr, W)
   is
      Leave : Pick;
      Enter : Choice;
      C     : Vector (1 .. Pr.N);
      Price : Vector (1 .. Pr.K);
   begin
      W.Cand := St;
      Solve_Vertex (Pr, W.Cost, Work, W.Cand, W.Ok);
      Leave := Worst_Excess (Pr, W.Cand, Work);
      W.Ended := not W.Ok or else not Names (Pr, Leave.In_Row, Leave.Place);
      if W.Ended then
         return;
      elsif Leave.Size <= Wide (S.Tol.Primal) then
         W.Now := Primal;
         return;
      end if;
      Leaving_Row (Pr, Work, Leave, C);
      Prices (Pr, Work, C, Price, W.Ok);
      Enter := Dual_Entering (Pr, Work, W.Cand, Price, Leave);
      W.Ended :=
        not W.Ok
        or else not Enter.Found
        or else not Names (Pr, Enter.In_Row, Enter.Place);
      if not W.Ended then
         Swap (Pr, Work, Enter, Leave);
      end if;
   end Dual_Step;

   ---------------------------------------------------------------------
   --  A primal pivot.
   ---------------------------------------------------------------------

   --  The first held inequality, boxes then rows, whose multiplier has the
   --  wrong sign: Bland's entering choice.
   function First_Push
     (Pr : Problem; Cand : State; Work : Workspace) return Pick
   with Pre => Fits_Work (Pr, Work) and then Fits_State (Pr, Cand)
   is
   begin
      for I in 1 .. Pr.N loop
         if Wrong_Push (Work.Box_Side (I), Cand.Y (I), Pr.Lo (I), Pr.Hi (I))
           > 0
         then
            return (1, False, I, Free);
         end if;
      end loop;
      for R in 1 .. Pr.K loop
         if Wrong_Push
              (Work.Row_Side (R), Cand.Y_Row (R), Pr.Row_Lo (R), Pr.Row_Hi (R))
           > 0
         then
            return (1, True, R, Free);
         end if;
      end loop;
      return (others => <>);
   end First_Push;

   --  The edge's right side over the held rows, packed: what holding the
   --  other rows asks of the free variables as the entering constraint
   --  moves off its bound by one.
   procedure Edge_Side
     (Pr : Problem; Work : Workspace; Enter : Pick; V : out Vector)
   with
     Pre =>
       Packed (Pr, Work)
       and then V'First = 1
       and then V'Last = Pr.K
       and then Names (Pr, Enter.In_Row, Enter.Place)
   is
   begin
      V := [others => 0];
      for P in 1 .. Work.Row_Count loop
         if Enter.In_Row then
            V (P) :=
              (if Work.Row_At (P) = Enter.Place
               then
                 (if Work.Row_Side (Enter.Place) = At_Upper then -One else One)
               else 0);
         else
            V (P) :=
              (if Work.Box_Side (Enter.Place) = At_Upper
               then Pr.E (Work.Row_At (P), Enter.Place)
               else -Pr.E (Work.Row_At (P), Enter.Place));
         end if;
      end loop;
   end Edge_Side;

   --  The edge over every variable: the free ones' Z unpacked, the
   --  entering variable's unit off its bound.
   procedure Edge
     (Pr    : Problem;
      Work  : Workspace;
      Enter : Pick;
      Z     : Vector;
      Dx    : out Vector)
   with
     Pre =>
       Packed (Pr, Work)
       and then Z'First = 1
       and then Z'Last = Pr.N
       and then Dx'First = 1
       and then Dx'Last = Pr.N
       and then (if not Enter.In_Row then Enter.Place <= Pr.N)
   is
   begin
      Dx := [others => 0];
      for Q in 1 .. Work.Free_Count loop
         Dx (Work.Free_At (Q)) := Z (Q);
      end loop;
      if not Enter.In_Row then
         Dx (Enter.Place) :=
           (if Work.Box_Side (Enter.Place) = At_Upper then -One else One);
      end if;
   end Edge;

   --  The choice a basic constraint at A in [Lo, Hi], moving at Rate,
   --  offers a primal ratio test: the bound it reaches, how soon.  The
   --  caller names the constraint.
   function Primal_Offer (A : Wide; Rate : Wide; Lo, Hi : Val) return Choice
   is (if Rate > Rate_Floor and then Hi /= No_Upper
       then
         (True,
          Ratio_Of (Wide'Max (0, Wide (Hi) - A), Rate),
          False,
          Index'First,
          At_Upper)
       elsif Rate < -Rate_Floor and then Lo /= No_Lower
       then
         (True,
          Ratio_Of (Wide'Max (0, A - Wide (Lo)), -Rate),
          False,
          Index'First,
          At_Lower)
       else (others => <>))
   with
     Pre =>
       A in -(4 * Val_Bound) .. 4 * Val_Bound
       and then Rate in -(4 * Rate_Bound) .. 4 * Rate_Bound;

   --  The entering constraint's own range, as a flip of its side.
   function Own_Offer (Pr : Problem; Enter : Pick) return Choice
   is (if Enter.In_Row
       then
         (if Pr.Row_Lo (Enter.Place) /= No_Lower
            and then Pr.Row_Hi (Enter.Place) /= No_Upper
          then
            (True,
             Wide (Pr.Row_Hi (Enter.Place)) - Wide (Pr.Row_Lo (Enter.Place)),
             True,
             Enter.Place,
             Free)
          else (others => <>))
       elsif Pr.Lo (Enter.Place) /= No_Lower
         and then Pr.Hi (Enter.Place) /= No_Upper
       then
         (True,
          Wide (Pr.Hi (Enter.Place)) - Wide (Pr.Lo (Enter.Place)),
          False,
          Enter.Place,
          Free)
       else (others => <>))
   with Pre => Names (Pr, Enter.In_Row, Enter.Place);

   --  The leaving constraint of a primal pivot along Dx: the basic one
   --  that first reaches a bound, or the entering one's own range.
   function Primal_Leaving
     (Pr : Problem; Work : Workspace; Cand : State; Dx : Vector; Enter : Pick)
      return Choice
   with
     Pre =>
       Fits_Work (Pr, Work)
       and then Fits_State (Pr, Cand)
       and then Dx'First = 1
       and then Dx'Last = Pr.N
       and then Names (Pr, Enter.In_Row, Enter.Place)
   is
      C : Choice := Own_Offer (Pr, Enter);
   begin
      for I in 1 .. Pr.N loop
         if Is_Free (Work, I) then
            Keep_Smaller
              (C,
               (Primal_Offer
                  (Wide (Cand.X (I)), Wide (Dx (I)), Pr.Lo (I), Pr.Hi (I))
                with delta Place => I));
         end if;
      end loop;
      for R in 1 .. Pr.K loop
         if not Is_Held_Row (Work, R) and then not Cones.In_Cone (Pr, R) then
            Keep_Smaller
              (C,
               (Primal_Offer
                  (Held_To (Certificate.Row_Of (Pr, R, Cand.X), 4 * Val_Bound),
                   Held_To (Certificate.Row_Of (Pr, R, Dx), 4 * Rate_Bound),
                   Pr.Row_Lo (R),
                   Pr.Row_Hi (R))
                with delta In_Row => True, Place => R));
         end if;
      end loop;
      return C;
   end Primal_Leaving;

   --  Work's sides after a primal pivot: a flip of the entering side, or
   --  the entering released and the leaving held.
   procedure Pivot
     (Pr : Problem; Work : in out Workspace; Enter : Pick; Leave : Choice)
   with
     Pre =>
       Fits_Work (Pr, Work)
       and then Names (Pr, Enter.In_Row, Enter.Place)
       and then Names (Pr, Leave.In_Row, Leave.Place)
   is
   begin
      if Leave.To = Free and then Enter.In_Row then
         Work.Row_Side (Enter.Place) :=
           (if Work.Row_Side (Enter.Place) = At_Upper
            then At_Lower
            else At_Upper);
      elsif Leave.To = Free then
         Work.Box_Side (Enter.Place) :=
           (if Work.Box_Side (Enter.Place) = At_Upper
            then At_Lower
            else At_Upper);
      else
         Swap
           (Pr,
            Work,
            (True, 0, Enter.In_Row, Enter.Place, Free),
            (0, Leave.In_Row, Leave.Place, Leave.To));
      end if;
   end Pivot;

   --  One step of the primal walk: the vertex for the problem's cost; it
   --  ends the walk when certified; when infeasible the walk turns dual
   --  again; else a held constraint with the wrong sign enters and the
   --  basic one that first reaches a bound along its edge leaves.
   procedure Primal_Step
     (Pr   : Problem;
      S    : Settings;
      Work : in out Workspace;
      St   : State;
      W    : in out Walk)
   with
     Pre =>
       Fits_Work (Pr, Work)
       and then Fits_State (Pr, St)
       and then Fits_Walk (Pr, W)
   is
      Enter : Pick;
      Leave : Choice;
      V     : Vector (1 .. Pr.K);
      Z     : Vector (1 .. Pr.N);
      Dx    : Vector (1 .. Pr.N);
   begin
      W.Cand := St;
      Solve_Vertex (Pr, Pr.Q, Work, W.Cand, W.Ok);
      W.Ended := not W.Ok or else Certificate.Certified (Pr, W.Cand, S.Tol);
      if W.Ended then
         return;
      elsif Worst_Excess (Pr, W.Cand, Work).Size > Wide (S.Tol.Primal) then
         Shift (Pr, Work, St, W);
         return;
      end if;
      Enter :=
        (if W.Bland
         then First_Push (Pr, W.Cand, Work)
         else Worst_Push (Pr, W.Cand, Work));
      W.Ended := Enter.Size = 0;
      if W.Ended or else not Names (Pr, Enter.In_Row, Enter.Place) then
         return;
      end if;
      Edge_Side (Pr, Work, Enter, V);
      Direction (Pr, Work, V, Z, W.Ok);
      Edge (Pr, Work, Enter, Z, Dx);
      Leave := Primal_Leaving (Pr, Work, W.Cand, Dx, Enter);
      W.Ended :=
        not W.Ok
        or else not Leave.Found
        or else not Names (Pr, Leave.In_Row, Leave.Place);
      W.Bland := Leave.Found and then Leave.Ratio <= Wide (S.Tol.Primal);
      if not W.Ended then
         Pivot (Pr, Work, Enter, Leave);
      end if;
   end Primal_Step;

   ---------------------------------------------------------------------
   --  The walk.
   ---------------------------------------------------------------------

   --  W walked from St: Work's held set read off it and made a basis, the
   --  cost shifted, and up to S.Pivots steps taken.
   procedure Walk_From
     (Pr   : Problem;
      S    : Settings;
      Work : in out Workspace;
      St   : State;
      W    : in out Walk)
   with
     Pre =>
       Fits_Work (Pr, Work)
       and then Fits_State (Pr, St)
       and then Fits_Walk (Pr, W)
   is
   begin
      Read_Held (Pr, St, Work);
      Make_Basis (Pr, St, Work, W.Ok);
      if W.Ok then
         Shift (Pr, Work, St, W);
      end if;
      for Step in 1 .. S.Pivots loop
         exit when W.Ended or else not W.Ok;
         if W.Now = Dual then
            Dual_Step (Pr, S, Work, St, W);
         else
            Primal_Step (Pr, S, Work, St, W);
         end if;
      end loop;
   end Walk_From;

   procedure Run
     (Pr     : Problem;
      S      : Settings;
      Work   : in out Workspace;
      St     : in out State;
      Passed : out Boolean)
   is
      W : Walk (Pr.N, Pr.K) :=
        (N     => Pr.N,
         K     => Pr.K,
         Cand  => St,
         Cost  => Pr.Q,
         Now   => Dual,
         Bland => False,
         Ended => False,
         Ok    => True);
   begin
      Passed := False;
      if S.Pivots = 0 or else Cones.Has_Cone (Pr) or else not Is_Linear (Pr)
      then
         return;
      end if;
      Walk_From (Pr, S, Work, St, W);
      if W.Ok and then Certificate.Certified (Pr, W.Cand, S.Tol) then
         St := W.Cand;
         Passed := True;
      end if;
   end Run;

end Abacus.Qp.Crossover;
