package body Spike.Deltas
  with SPARK_Mode
is

   function Term (A, B : Fix) return Acc
   is (Acc (A * B))
   with Pre => Roomy, Post => Term'Result in -Term_Max .. Term_Max;

   function Dot
     (M : Fix_Matrix; I, J : Index; From : Positive; To : Count) return Acc
   is
      S : Acc := 0.0;
   begin
      for K in From .. To loop
         S := S + Term (M (I, K), M (J, K));
         pragma
           Loop_Invariant
             (S in -Sum_Max (K - From + 1) .. Sum_Max (K - From + 1));
      end loop;
      return S;
   end Dot;

   function Dot
     (M : Fix_Matrix; I : Index; V : Fix_Vector; From : Positive; To : Count)
      return Acc
   is
      S : Acc := 0.0;
   begin
      for K in From .. To loop
         S := S + Term (M (I, K), V (K));
         pragma
           Loop_Invariant
             (S in -Sum_Max (K - From + 1) .. Sum_Max (K - From + 1));
      end loop;
      return S;
   end Dot;

   --  Bit by bit, as Spike.Kernels.Root, then rounded to nearest.
   function Root (X : Acc) return Fix is
      R    : Fix := 0.0;
      Step : Fix := Fix'Last / 2;
   begin
      for B in 0 .. 63 loop
         if R <= Fix'Last - Step and then Term (R + Step, R + Step) <= X then
            R := R + Step;
         end if;
         Step := Step / 2;
         pragma Loop_Invariant (R >= 0.0 and then Step >= 0.0);
      end loop;
      return
        (if R < Fix'Last and then X - Term (R, R) > Acc (R * Fix'(Fix'Small))
         then R + Fix'Small
         else R);
   end Root;

   --  S / P to the nearest value, if it fits.  SPARK does not take
   --  Fix'Round of a quotient, so the conversion truncates and the
   --  remainder decides the last unit.
   procedure Quotient (S : Acc; P : Pivot; Q : out Fix; Ok : out Boolean)
   with Pre => Roomy
   is
      Half : constant Acc := Term (P, Fix'Small) / 2;
   begin
      Ok := abs S < Term (P, Fix'Last - Fix'Small);
      if not Ok then
         Q := 0.0;
         return;
      end if;
      Q := Fix (S / P);
      if S - Term (Q, P) >= Half then
         Q := Q + Fix'Small;
      elsif S - Term (Q, P) <= -Half then
         Q := Q - Fix'Small;
      end if;
   end Quotient;

   procedure Factor_Row
     (A       : in out Fix_Matrix;
      D       : in out Pivots;
      I       : Index;
      Floor   : Pivot;
      Outcome : out Outcome_Kind)
   with
     Pre =>
       Roomy
       and then Is_Square (A)
       and then I in A'Range (1)
       and then D'First = A'First (1)
       and then D'Last = A'Last (1)
   is
      Q  : Fix;
      Ok : Boolean;
      S  : Acc;
      R  : Fix;
   begin
      for J in A'First (1) .. I - 1 loop
         Quotient
           (Acc (A (I, J)) - Dot (A, I, J, A'First (2), J - 1), D (J), Q, Ok);
         if not Ok then
            Outcome := Out_Of_Range;
            return;
         end if;
         A (I, J) := Q;
      end loop;
      S := Acc (A (I, I)) - Dot (A, I, I, A'First (2), I - 1);
      if S < 0.0 or else S >= Term_Max then
         Outcome := Not_Positive_Definite;
         return;
      end if;
      R := Root (S);
      if R < Floor then
         Outcome := Not_Positive_Definite;
      else
         D (I) := R;
         A (I, I) := R;
         Outcome := Done;
      end if;
   end Factor_Row;

   procedure Mirror (A : in out Fix_Matrix) with Pre => Is_Square (A) is
   begin
      for I in A'Range (1) loop
         for J in A'First (1) .. I - 1 loop
            A (J, I) := A (I, J);
         end loop;
      end loop;
   end Mirror;

   procedure Factor
     (A       : in out Fix_Matrix;
      D       : out Pivots;
      Floor   : Pivot;
      Outcome : out Outcome_Kind) is
   begin
      D := [others => Fix'Last];
      Outcome := Done;
      for I in A'Range (1) loop
         Factor_Row (A, D, I, Floor, Outcome);
         exit when Outcome /= Done;
      end loop;
      if Outcome = Done then
         Mirror (A);
      end if;
   end Factor;

   procedure Solve_Entry
     (L    : Fix_Matrix;
      D    : Pivots;
      B    : in out Fix_Vector;
      I    : Index;
      From : Positive;
      To   : Count;
      Ok   : out Boolean)
   with
     Pre =>
       Roomy
       and then Is_Square (L)
       and then I in L'Range (1)
       and then D'First = L'First (1)
       and then D'Last = L'Last (1)
       and then B'First = L'First (1)
       and then B'Last = L'Last (1)
       and then (if From <= To
                 then From >= L'First (1) and then To <= L'Last (1))
   is
      Q : Fix;
   begin
      Quotient (Acc (B (I)) - Dot (L, I, B, From, To), D (I), Q, Ok);
      if Ok then
         B (I) := Q;
      end if;
   end Solve_Entry;

   procedure Solve
     (L       : Fix_Matrix;
      D       : Pivots;
      B       : in out Fix_Vector;
      Outcome : out Outcome_Kind)
   is
      Ok : Boolean := True;
   begin
      for I in L'Range (1) loop
         Solve_Entry (L, D, B, I, L'First (1), I - 1, Ok);
         exit when not Ok;
      end loop;
      if Ok then
         for I in reverse L'Range (1) loop
            Solve_Entry (L, D, B, I, I + 1, L'Last (1), Ok);
            exit when not Ok;
         end loop;
      end if;
      Outcome := (if Ok then Done else Out_Of_Range);
   end Solve;

end Spike.Deltas;
