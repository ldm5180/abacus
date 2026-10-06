with Abacus.Qp.Engine;

package body Abacus_Qp_Problems is

   function Two
     (Q : Vector := [0, 0]; Lo, Hi : Val := 0; Row_Lo, Row_Hi : Val := One)
      return Problem
   is ((N      => 2,
        K      => 1,
        P      => [[One, 0], [0, One]],
        Q      => Q,
        Lo     => [Lo, Lo],
        Hi     => [Hi, Hi],
        E      => [[One, One]],
        Row_Lo => [Row_Lo],
        Row_Hi => [Row_Hi]));

   function With_P (Pr : Problem; P : Matrix) return Problem is
      Result : Problem := Pr;
   begin
      Result.P := P;
      return Result;
   end With_P;

   function Solved
     (Pr : Problem; S : Settings; St : in out State) return Outcome
   is
      Work   : Workspace (Pr.N);
      Result : Outcome;
   begin
      Abacus.Qp.Engine.Solve (Pr, S, Work, St, Result);
      return Result;
   end Solved;

end Abacus_Qp_Problems;
