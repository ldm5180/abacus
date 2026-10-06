with Spike.Grid;
with Spike.Kernels; use Spike.Kernels;

package body Spike.Linear
  with SPARK_Mode
is

   package G is new Spike.Grid (Frac);
   One : constant Wide := G.One;

   function Fits (W : Wide) return Boolean
   is (W in Wide (Val'First) .. Wide (Val'Last));

   --  A (I, J) at scale One * One less the dot of rows I and J over the
   --  columns before J: what is left of the entry once the rows of L
   --  already known are taken out.
   function Remainder (A : Matrix; I, J : Index) return Numerator
   is (Wide (A (I, J)) * One - Dot (A, I, J, A'First (2), J - 1))
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
      Q : constant Wide := Div_Round (Remainder (A, I, J), D (J));
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
      if S >= Term_Bound then
         Result := Out_Of_Range;
         return;
      elsif S < 0 then
         Result := Not_Positive_Definite;
         return;
      end if;
      R := Root (S);
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
     Pre =>
       Is_Square (A)
       and then I in A'Range (1)
       and then D'First = A'First (1)
       and then D'Last = A'Last (1)
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

   --  The upper triangle from the lower, so a back solve reads rows.
   procedure Mirror (A : in out Matrix) with Pre => Is_Square (A) is
   begin
      for I in A'Range (1) loop
         for J in A'First (1) .. I - 1 loop
            A (J, I) := A (I, J);
         end loop;
      end loop;
   end Mirror;

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
      end loop;
      if Outcome.Result = Factored then
         Mirror (A);
      end if;
   end Factor;

end Spike.Linear;
