--  The constraints a held set picks to change: the held bound whose
--  multiplier pushes hardest the wrong way, and the free constraint an
--  answer lies furthest outside.  The polish and the crossover both pick
--  with them.

package Abacus.Qp.Picks
  with SPARK_Mode
is

   --  A constraint picked: how far it is wrong, whether it is a row,
   --  which, and the side it is to take.
   type Pick is record
      Size   : Wide := 0;
      In_Row : Boolean := False;
      Place  : Index := Index'First;
      To     : Side := Free;
   end record;

   --  The held bound whose multiplier pushes hardest the wrong way.
   function Worst_Push
     (Pr : Problem; Cand : State; Work : Workspace) return Pick
   with Pre => Fits_Work (Pr, Work) and then Fits_State (Pr, Cand);

   --  The free constraint Cand lies furthest outside, and the side it
   --  passes.
   function Worst_Excess
     (Pr : Problem; Cand : State; Work : Workspace) return Pick
   with Pre => Fits_Work (Pr, Work) and then Fits_State (Pr, Cand);

end Abacus.Qp.Picks;
