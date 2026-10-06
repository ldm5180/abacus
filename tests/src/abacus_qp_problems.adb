with Abacus.Arith;
with Abacus.Elementary;
with Abacus.Qp.Engine;
with Abacus.Random;

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

   --  A standard normal draw: the quantile of a uniform one on the grid.
   function Normal (G : in out Abacus.Random.Generator) return Val is
      use type Interfaces.Unsigned_64;
      U : Interfaces.Unsigned_64;
   begin
      Abacus.Random.Below (G, One - 1, U);
      return Abacus.Elementary.Inv_Norm_Cdf (Val (U) + 1);
   end Normal;

   --  A scaled by B, both values, rounded once.
   function Times (A, B : Val) return Val
   is (Val (Abacus.Arith.Product_Of (A, B)));

   Mean_Return : constant Val := One / 2_000;
   Own_Spread  : constant Val := One / 50;
   Common      : constant Val := One / 100;
   Cap         : constant Val := One / 20;

   --  The scenarios' returns into E's first rows and columns.
   procedure Draw_Returns
     (Pr : in out Problem; Columns : Positive; Seed : Interfaces.Unsigned_64)
   is
      G     : Abacus.Random.Generator := Abacus.Random.Seeded (Seed);
      Shock : Val;
   begin
      for S in 1 .. Pr.K - 1 loop
         Shock := Times (Common, Normal (G));
         for J in 1 .. Columns loop
            Pr.E (S, J) :=
              Mean_Return + Shock + Times (Own_Spread, Normal (G));
         end loop;
      end loop;
   end Draw_Returns;

   --  Each scenario's worst loss, -min_j r_sj, into Worst, and the least
   --  loss of any scenario, -max r, into Least.
   procedure Losses
     (Pr : Problem; Columns : Positive; Worst : out Vector; Least : out Val) is
   begin
      Worst := [others => Val'First];
      Least := Val'Last;
      for S in Worst'Range loop
         for J in 1 .. Columns loop
            Worst (S) := Val'Max (Worst (S), -Pr.E (S, J));
            Least := Val'Min (Least, -Pr.E (S, J));
         end loop;
      end loop;
   end Losses;

   --  The weights: each in 0 .. Cap, their sum one, their cost minus
   --  their mean over the scenarios.
   procedure Pose_Weights (Pr : in out Problem; Columns : Positive) is
      T   : constant Positive := Pr.K - 1;
      Sum : Wide;
   begin
      for J in 1 .. Columns loop
         Sum := 0;
         for S in 1 .. T loop
            Sum := Sum + Wide (Pr.E (S, J));
         end loop;
         Pr.Q (J) := Val (-Abacus.Arith.Div_Round (Sum, Wide (T)));
         Pr.Lo (J) := 0;
         Pr.Hi (J) := Cap;
         Pr.E (Pr.K, J) := One;
      end loop;
      Pr.Row_Lo := [others => 0];
      Pr.Row_Hi := [others => No_Upper];
      Pr.Row_Lo (Pr.K) := One;
      Pr.Row_Hi (Pr.K) := One;
   end Pose_Weights;

   --  The threshold a, between the least and the most loss, and each
   --  shortfall u_s, between zero and its scenario's worst loss less the
   --  least threshold; their costs one and 1 / (0.05 T).
   procedure Pose_Shortfalls (Pr : in out Problem; Columns : Positive) is
      T     : constant Positive := Pr.K - 1;
      A     : constant Index := Columns + 1;
      Worst : Vector (1 .. T);
      Least : Val;
   begin
      Losses (Pr, Columns, Worst, Least);
      Pr.Q (A) := One;
      Pr.Lo (A) := Least;
      Pr.Hi (A) := Least;
      for S in 1 .. T loop
         Pr.Hi (A) := Val'Max (Pr.Hi (A), Worst (S));
         Pr.E (S, A) := One;
         Pr.E (S, A + S) := One;
         Pr.Q (A + S) := 20 * One / Val (T);
         Pr.Lo (A + S) := 0;
         Pr.Hi (A + S) := Worst (S) - Least;
      end loop;
   end Pose_Shortfalls;

   procedure Pose_Tail
     (Pr : out Problem; Columns : Positive; Seed : Interfaces.Unsigned_64) is
   begin
      Pr.P := [others => [others => 0]];
      Pr.E := [others => [others => 0]];
      Draw_Returns (Pr, Columns, Seed);
      Pose_Weights (Pr, Columns);
      Pose_Shortfalls (Pr, Columns);
   end Pose_Tail;

   function Solved
     (Pr : Problem; S : Settings; St : in out State) return Outcome
   is
      Work   : Workspace (Pr.N, Pr.K);
      Result : Outcome;
   begin
      Abacus.Qp.Engine.Solve (Pr, S, Work, St, Result);
      return Result;
   end Solved;

end Abacus_Qp_Problems;
