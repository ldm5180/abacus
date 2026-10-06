with Spike.Grid;
with Spike.Kernels; use Spike.Kernels;

package body Spike.Estimate
  with SPARK_Mode
is

   package G is new Spike.Grid (Frac);
   One : constant Wide := G.One;

   Row_Bound : constant := Max_N * Val_Bound;

   --  The sum of row I.
   function Row_Sum (R : Matrix; I : Index) return Wide
   with
     Pre  => I in R'Range (1),
     Post => Row_Sum'Result in -Row_Bound .. Row_Bound
   is
      S : Wide := 0;
   begin
      for T in R'Range (2) loop
         S := S + Wide (R (I, T));
         pragma
           Loop_Invariant
             (S
              in -(Wide (T - R'First (2) + 1) * Val_Bound)
               .. Wide (T - R'First (2) + 1) * Val_Bound);
      end loop;
      return S;
   end Row_Sum;

   --  Row I less V, each entry checked into range.
   procedure Center (R : in out Matrix; I : Index; V : Val; Ok : out Boolean)
   with Pre => I in R'Range (1)
   is
   begin
      Ok := True;
      for T in R'Range (2) loop
         Ok := Fits (Wide (R (I, T)) - Wide (V));
         exit when not Ok;
         R (I, T) := R (I, T) - V;
      end loop;
   end Center;

   --  Row I times S, rounded, each entry checked into range.
   procedure Scale (R : in out Matrix; I : Index; S : Val; Ok : out Boolean)
   with Pre => I in R'Range (1)
   is
      P : Wide;
   begin
      Ok := True;
      for T in R'Range (2) loop
         P := G.Round (Wide (R (I, T)) * Wide (S));
         Ok := Fits (P);
         exit when not Ok;
         R (I, T) := Val (P);
      end loop;
   end Scale;

   --  A variance at scale One * One, raised by fours while it stays a
   --  root argument, beside One * One and one each raised by twos: the
   --  root of V over Unit is the deviation, Top over that root the
   --  inverse, both with the digits a small deviation would lose.
   type Lifted is record
      V    : Root_Arg;
      Top  : Wide;
      Unit : Wide;
   end record;

   Max_Lift : constant := 20;
   Top_Max  : constant := 2**124;

   function Lift (V : Root_Arg) return Lifted
   with
     Post =>
       Lift'Result.Top in 1 .. Top_Max
       and then Lift'Result.Unit in 1 .. 2**Max_Lift
   is
      L : Lifted := (V, One * One, 1);
   begin
      for Step in 1 .. Max_Lift loop
         exit when
           L.V >= Term_Bound / 4
           or else L.Top > Top_Max / 2
           or else L.Unit > 2**(Max_Lift - 1);
         L := (L.V * 4, L.Top * 2, L.Unit * 2);
         pragma
           Loop_Invariant
             (L.Top in 1 .. Top_Max and then L.Unit in 1 .. 2**Max_Lift);
      end loop;
      return L;
   end Lift;

   --  A deviation and its inverse, both at scale One; a zero deviation
   --  means the row did not move.
   type Spread is record
      Sigma : Wide;
      Inv   : Wide;
   end record;

   function Spread_Of (V : Root_Arg) return Spread is
      L : constant Lifted := Lift (V);
      R : constant Val := Root (L.V);
   begin
      if R < 1 then
         return (0, 0);
      end if;
      return (Div_Round (Wide (R), L.Unit), Div_Round (L.Top, Wide (R)));
   end Spread_Of;

   --  Row I's moments into M, and its z-scores in place.
   procedure Standardize_Row
     (R      : in out Matrix;
      I      : Index;
      M      : in out Moments;
      Result : out Estimate_Result)
   with
     Pre =>
       R'First (1) = 1
       and then R'Last (1) = M.N
       and then I <= M.N
       and then R'First (2) = 1
       and then R'Last (2) >= 2
   is
      Days : constant Wide := Wide (R'Length (2));
      Mean : constant Wide := Div_Round (Row_Sum (R, I), Days);
      Ok   : Boolean;
      V    : Wide;
      S    : Spread;
   begin
      Result := Out_Of_Range;
      if not Fits (Mean) then
         return;
      end if;
      Center (R, I, Val (Mean), Ok);
      V :=
        (if Ok
         then Div_Round (Dot (R, I, I, R'First (2), R'Last (2)), Days - 1)
         else -1);
      if V not in Root_Arg then
         return;
      end if;
      S := Spread_Of (V);
      if S.Sigma < 1 then
         Result := Degenerate;
      elsif Fits (S.Sigma) and then Fits (S.Inv) then
         M.Mean (I) := Val (Mean);
         M.Sigma (I) := Val (S.Sigma);
         M.Inv_Sigma (I) := Val (S.Inv);
         Scale (R, I, Val (S.Inv), Ok);
         Result := (if Ok then Estimated else Out_Of_Range);
      end if;
   end Standardize_Row;

   procedure Standardize
     (R : in out Matrix; M : out Moments; Outcome : out Estimate_Outcome)
   is
      Result : Estimate_Result;
   begin
      M :=
        (N         => M.N,
         Mean      => [others => 0],
         Sigma     => [others => 0],
         Inv_Sigma => [others => 0]);
      Outcome := (Estimated, 0);
      for I in R'Range (1) loop
         Standardize_Row (R, I, M, Result);
         if Result /= Estimated then
            Outcome := (Result, I);
            return;
         end if;
      end loop;
   end Standardize;

   procedure Correlate
     (Z : Matrix; C : out Matrix; Outcome : out Estimate_Outcome)
   is
      Scale : constant Wide := Wide (Z'Length (2) - 1) * One;
      Q     : Wide;
   begin
      C := [others => [others => 0]];
      Outcome := (Estimated, 0);
      for I in Z'Range (1) loop
         for J in Z'First (1) .. I loop
            Q := Div_Round (Dot (Z, I, J, Z'First (2), Z'Last (2)), Scale);
            if not Fits (Q) then
               Outcome := (Out_Of_Range, I);
               return;
            end if;
            C (I, J) := Val (Q);
            C (J, I) := Val (Q);
         end loop;
      end loop;
   end Correlate;

end Spike.Estimate;
