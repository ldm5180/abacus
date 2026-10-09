with Abacus.Qp.Cones;
with Abacus.Qp.Held; use Abacus.Qp.Held;

package body Abacus.Qp.Polish
  with SPARK_Mode
is

   procedure Read_Held (Pr : Problem; St : State; Work : in out Workspace)
   renames Held.Read_Held;

   procedure Solve_Held
     (Pr   : Problem;
      Work : in out Workspace;
      From : State;
      Cand : out State;
      Ok   : out Boolean) is
   begin
      Cand := From;
      Held.Solve (Pr, Pr.Q, Work, Cand, Ok);
   end Solve_Held;

   ---------------------------------------------------------------------
   --  Corrections.
   ---------------------------------------------------------------------

   --  A constraint picked for correction: how far it is wrong, whether it
   --  is a row, which, and the side it is to take.
   type Pick is record
      Size   : Wide := 0;
      In_Row : Boolean := False;
      Place  : Index := Index'First;
      To     : Side := Free;
   end record;

   --  How hard a held side's multiplier Y pushes the wrong way: a lower
   --  bound's must not be positive, an upper's not negative.  An
   --  equality holds either way.
   function Wrong_Push (S : Side; Y, Lo, Hi : Val) return Wide
   is (if Lo = Hi
       then 0
       elsif S = At_Lower and then Y > 0
       then Wide (Y)
       elsif S = At_Upper and then Y < 0
       then -Wide (Y)
       else 0);

   --  The side a value A past [Lo, Hi] passes.
   function Passed_Side (A : Wide; Hi : Val) return Side
   is (if A > Wide (Hi) then At_Upper else At_Lower);

   --  P with the candidate (Size, In_Row, Place, To) when it is larger.
   procedure Keep_Larger (P : in out Pick; Candidate : Pick) is
   begin
      if Candidate.Size > P.Size then
         P := Candidate;
      end if;
   end Keep_Larger;

   --  The held bound whose multiplier pushes hardest the wrong way.
   function Worst_Push
     (Pr : Problem; Cand : State; Work : Workspace) return Pick
   with Pre => Fits_Work (Pr, Work) and then Fits_State (Pr, Cand)
   is
      P : Pick;
   begin
      for I in 1 .. Pr.N loop
         Keep_Larger
           (P,
            (Wrong_Push (Work.Box_Side (I), Cand.Y (I), Pr.Lo (I), Pr.Hi (I)),
             False,
             I,
             Free));
      end loop;
      for R in 1 .. Pr.K loop
         Keep_Larger
           (P,
            (Wrong_Push
               (Work.Row_Side (R),
                Cand.Y_Row (R),
                Pr.Row_Lo (R),
                Pr.Row_Hi (R)),
             True,
             R,
             Free));
      end loop;
      return P;
   end Worst_Push;

   --  The free constraint Cand lies furthest outside.
   function Worst_Excess
     (Pr : Problem; Cand : State; Work : Workspace) return Pick
   with Pre => Fits_Work (Pr, Work) and then Fits_State (Pr, Cand)
   is
      P : Pick;
   begin
      for I in 1 .. Pr.N loop
         if Is_Free (Work, I) then
            Keep_Larger
              (P,
               (Certificate.Outside (Wide (Cand.X (I)), Pr.Lo (I), Pr.Hi (I)),
                False,
                I,
                Passed_Side (Wide (Cand.X (I)), Pr.Hi (I))));
         end if;
      end loop;
      for R in 1 .. Pr.K loop
         if not Is_Held_Row (Work, R) and then not Cones.In_Cone (Pr, R) then
            Keep_Larger
              (P,
               (Certificate.Outside
                  (Certificate.Row_Of (Pr, R, Cand.X),
                   Pr.Row_Lo (R),
                   Pr.Row_Hi (R)),
                True,
                R,
                Passed_Side
                  (Certificate.Row_Of (Pr, R, Cand.X), Pr.Row_Hi (R))));
         end if;
      end loop;
      return P;
   end Worst_Excess;

   --  How many of Work's sides are held.
   function Held_Count (S : Sides) return Natural is
      C : Natural := 0;
   begin
      for I in S'Range loop
         if S (I) /= Free then
            C := C + 1;
         end if;
         pragma Loop_Invariant (C <= I - S'First + 1);
      end loop;
      return C;
   end Held_Count;

   --  Whether Work holds more general rows than it frees variables: the
   --  held rows cannot then all be met.
   function Overheld (Work : Workspace) return Boolean
   is (Held_Count (Work.Row_Side) > Work.N - Held_Count (Work.Box_Side));

   --  |Y| for a multiplier.
   function Pull_Of (Y : Val) return Wide
   is (if Y < 0 then -Wide (Y) else Wide (Y));

   --  The held inequality, a bound or a row, whose multiplier pulls least,
   --  to be released; none (a Pick of size zero) when every held
   --  constraint is an equality.
   function Weakest_Held
     (Pr : Problem; Cand : State; Work : Workspace) return Pick
   with Pre => Fits_Work (Pr, Work) and then Fits_State (Pr, Cand)
   is
      P     : Pick;
      Least : Wide := Wide (Val'Last) + 1;
   begin
      for I in 1 .. Pr.N loop
         if Work.Box_Side (I) /= Free
           and then Pr.Lo (I) /= Pr.Hi (I)
           and then Pull_Of (Cand.Y (I)) < Least
         then
            Least := Pull_Of (Cand.Y (I));
            P := (1, False, I, Free);
         end if;
      end loop;
      for R in 1 .. Pr.K loop
         if Is_Held_Row (Work, R)
           and then Pr.Row_Lo (R) /= Pr.Row_Hi (R)
           and then Pull_Of (Cand.Y_Row (R)) < Least
         then
            Least := Pull_Of (Cand.Y_Row (R));
            P := (1, True, R, Free);
         end if;
      end loop;
      return P;
   end Weakest_Held;

   procedure Correct
     (Pr      : Problem;
      Cand    : State;
      Work    : in out Workspace;
      Changed : out Boolean)
   is
      P : Pick := Worst_Push (Pr, Cand, Work);
   begin
      if P.Size = 0 then
         P := Worst_Excess (Pr, Cand, Work);
      end if;
      if P.Size = 0 and then Overheld (Work) then
         P := Weakest_Held (Pr, Cand, Work);
      end if;
      Changed := P.Size > 0;
      if Changed and then P.In_Row and then P.Place <= Pr.K then
         Work.Row_Side (P.Place) := P.To;
      elsif Changed and then P.Place <= Pr.N then
         Work.Box_Side (P.Place) := P.To;
      end if;
   end Correct;

   --  The bounds just read off the iterate, remembered as the last a
   --  polish is tried from.
   procedure Remember (Work : in out Workspace) is
   begin
      Work.Tried := True;
      Work.Tried_Box := Work.Box_Side;
      Work.Tried_Row := Work.Row_Side;
   end Remember;

   --  The problem solved with Work's sides held, corrected up to
   --  S.Corrections times until its answer is certified: Run's search.
   procedure Search
     (Pr     : Problem;
      S      : Settings;
      Work   : in out Workspace;
      St     : in out State;
      Passed : out Boolean)
   with
     Pre  => Fits_Work (Pr, Work) and then Fits_State (Pr, St),
     Post =>
       (if Passed then Certificate.Certified (Pr, St, S.Tol) else St = St'Old)
   is
      Cand    : State (Pr.N, Pr.K);
      Ok      : Boolean;
      Changed : Boolean;
   begin
      Passed := False;
      for Round in 0 .. S.Corrections loop
         Solve_Held (Pr, Work, St, Cand, Ok);
         exit when not Ok;
         if Certificate.Certified (Pr, Cand, S.Tol) then
            St := Cand;
            Passed := True;
            exit;
         end if;
         Correct (Pr, Cand, Work, Changed);
         exit when not Changed;
         pragma Loop_Invariant (not Passed and then St = St'Loop_Entry);
      end loop;
   end Search;

   procedure Run
     (Pr     : Problem;
      S      : Settings;
      Work   : in out Workspace;
      St     : in out State;
      Passed : out Boolean) is
   begin
      Passed := False;
      if Cones.Has_Cone (Pr) then
         return;
      end if;
      Read_Held (Pr, St, Work);
      if not Tried_Before (Work) then
         Remember (Work);
         Search (Pr, S, Work, St, Passed);
      end if;
   end Run;

end Abacus.Qp.Polish;
