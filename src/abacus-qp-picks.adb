with Abacus.Qp.Certificate;
with Abacus.Qp.Cones;
with Abacus.Qp.Held; use Abacus.Qp.Held;

package body Abacus.Qp.Picks
  with SPARK_Mode
is

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

   function Worst_Push
     (Pr : Problem; Cand : State; Work : Workspace) return Pick
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

   function Worst_Excess
     (Pr : Problem; Cand : State; Work : Workspace) return Pick
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

end Abacus.Qp.Picks;
