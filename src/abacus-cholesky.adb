with Abacus.Arith;    use Abacus.Arith;
with Abacus.Elementary;
with Abacus.Matrices; use Abacus.Matrices;

package body Abacus.Cholesky
  with SPARK_Mode
is

   --  A (I, J) at scale One * One less the dot of rows I and J over the
   --  columns before J: what is left of the entry once the rows of L
   --  already known are taken out.
   function Remainder (A : Matrix; I, J : Index) return Product
   is (Wide (A (I, J)) * One - Row_Dot (A, I, J, A'First (2), J - 1))
   with
     Pre => Is_Square (A) and then I in A'Range (1) and then J in A'Range (1);

   --  L (I, J) = (A (I, J) - the dot of rows I and J so far) / D (J).
   procedure Off_Diagonal
     (A : in out Matrix; D : Pivots; I, J : Index; Ok : out Boolean)
   with
     Pre =>
       Is_Square (A)
       and then I in A'Range (1)
       and then J in A'Range (1)
       and then D'First = A'First (1)
       and then D'Last = A'Last (1)
   is
      Q : constant Wide := Div_Round (Remainder (A, I, J), Wide (D (J)));
   begin
      Ok := Fits (Q);
      if Ok then
         A (I, J) := Val (Q);
      end if;
   end Off_Diagonal;

   --  D (I) = the root of (A (I, I) - the dot of row I with itself so far).
   procedure Diagonal
     (A      : in out Matrix;
      D      : in out Pivots;
      I      : Index;
      Floor  : Pivot;
      Result : out Factor_Result)
   with
     Pre =>
       Is_Square (A)
       and then I in A'Range (1)
       and then D'First = A'First (1)
       and then D'Last = A'Last (1)
   is
      S : constant Wide := Remainder (A, I, I);
      R : Val;
   begin
      if S > Elementary.Root_Arg'Last then
         Result := Out_Of_Range;
         return;
      elsif S < 0 then
         Result := Not_Positive_Definite;
         return;
      end if;
      R := Elementary.Root (S);
      if R < Floor then
         Result := Not_Positive_Definite;
      else
         D (I) := R;
         A (I, I) := R;
         Result := Factored;
      end if;
   end Diagonal;

   --  Row I of L, left to right, then its pivot.
   procedure Factor_Row
     (A       : in out Matrix;
      D       : in out Pivots;
      I       : Index;
      Floor   : Pivot;
      Outcome : out Factor_Outcome)
   with
     Pre  =>
       Is_Square (A)
       and then I in A'Range (1)
       and then D'First = A'First (1)
       and then D'Last = A'Last (1),
     Post =>
       (if Outcome.Result = Factored
        then Outcome.Column = 0
        else Outcome.Column in A'Range (1))
   is
      Ok     : Boolean;
      Result : Factor_Result;
   begin
      for J in A'First (1) .. I - 1 loop
         Off_Diagonal (A, D, I, J, Ok);
         if not Ok then
            Outcome := (Out_Of_Range, J);
            return;
         end if;
      end loop;
      Diagonal (A, D, I, Floor, Result);
      Outcome := (Result, (if Result = Factored then 0 else I));
   end Factor_Row;

   procedure Factor
     (A       : in out Matrix;
      D       : out Pivots;
      Floor   : Pivot;
      Outcome : out Factor_Outcome) is
   begin
      D := [others => 1];
      Outcome := (Factored, 0);
      for I in A'Range (1) loop
         Factor_Row (A, D, I, Floor, Outcome);
         exit when Outcome.Result /= Factored;
         pragma Loop_Invariant (Outcome = (Factored, 0));
      end loop;
      if Outcome.Result = Factored then
         Mirror (A);
      end if;
   end Factor;

   --  Which entry of a triangular solve, and the columns its row is
   --  dotted over: From .. To, empty for the first entry of a pass.
   type Solve_Span is record
      Row  : Index;
      From : Positive;
      To   : Count;
   end record;

   --  Entry Row of a triangular solve: (B (Row) - the dot of row Row of
   --  L with B over From .. To) / D (Row), stored if it fits.
   procedure Solve_Entry
     (L  : Matrix;
      D  : Pivots;
      B  : in out Vector;
      E  : Solve_Span;
      Ok : out Boolean)
   with
     Pre =>
       Is_Square (L)
       and then E.Row in L'Range (1)
       and then D'First = L'First (1)
       and then D'Last = L'Last (1)
       and then B'First = L'First (1)
       and then B'Last = L'Last (1)
       and then (if E.From <= E.To
                 then E.From >= L'First (1) and then E.To <= L'Last (1))
   is
      Q : constant Wide :=
        Div_Round
          (Wide (B (E.Row)) * One - Row_Vector_Dot (L, E.Row, B, E.From, E.To),
           Wide (D (E.Row)));
   begin
      Ok := Fits (Q);
      if Ok then
         B (E.Row) := Val (Q);
      end if;
   end Solve_Entry;

   procedure Solve
     (L : Matrix; D : Pivots; B : in out Vector; Result : out Solve_Result)
   is
      Ok : Boolean := True;
   begin
      for I in L'Range (1) loop
         Solve_Entry (L, D, B, (I, L'First (1), I - 1), Ok);
         exit when not Ok;
      end loop;
      if Ok then
         for I in reverse L'Range (1) loop
            Solve_Entry (L, D, B, (I, I + 1, L'Last (1)), Ok);
            exit when not Ok;
         end loop;
      end if;
      Result := (if Ok then Solved else Out_Of_Range);
   end Solve;

   --  The normal equations G Beta = C of a least-squares fit.
   type System (N : Index) is record
      G : Matrix (1 .. N, 1 .. N);
      C : Vector (1 .. N);
   end record;

   --  G = X'X + Ridge I and C = X'Y; Ok is False when an entry does not
   --  fit.
   procedure Normal_Equations
     (X : Matrix; Y : Vector; Ridge : Val; S : out System; Ok : out Boolean)
   with
     Pre =>
       X'Length (1) <= Max_N
       and then X'First (2) = 1
       and then X'Last (2) = S.N
       and then Y'First = X'First (1)
       and then Y'Last = X'Last (1)
   is
   begin
      Gram (X, S.G, Ok);
      S.C := [others => 0];
      for I in X'Range (2) loop
         Store (Wide (S.G (I, I)) + Wide (Ridge), S.G (I, I), Ok);
         Store (Round_Shift (Column_Vector_Dot (X, I, Y)), S.C (I), Ok);
      end loop;
   end Normal_Equations;

   procedure Least_Squares
     (X       : Matrix;
      Y       : Vector;
      Ridge   : Val;
      Beta    : out Vector;
      Outcome : out Factor_Outcome)
   is
      S      : System (X'Length (2));
      D      : Pivots (1 .. X'Length (2));
      Ok     : Boolean;
      Solved : Solve_Result;
   begin
      Beta := [others => 0];
      Normal_Equations (X, Y, Ridge, S, Ok);
      if not Ok then
         Outcome := (Out_Of_Range, 1);
         return;
      end if;
      Factor (S.G, D, 1, Outcome);
      if Outcome.Result = Factored then
         Solve (S.G, D, S.C, Solved);
         Beta := S.C;
         if Solved /= Cholesky.Solved then
            Outcome := (Out_Of_Range, 1);
         end if;
      end if;
   end Least_Squares;

end Abacus.Cholesky;
