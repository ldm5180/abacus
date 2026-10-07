with Interfaces;

with Abacus;    use Abacus;
with Abacus.Qp; use Abacus.Qp;

--  Small quadratic programs the solver's tests share: two variables
--  with the identity as P, in a box, with one row.  Not a library
--  unit's tests: the fixtures they are built from.

package Abacus_Qp_Problems is

   --  Minimize (1/2) x'x + Q'x with Lo <= x <= Hi and Row_Lo <= x1 + x2
   --  <= Row_Hi.
   function Two
     (Q : Vector := [0, 0]; Lo, Hi : Val := 0; Row_Lo, Row_Hi : Val := One)
      return Problem;

   --  Minimize Q'x over x in Lo .. Hi with ||x|| <= Radius: two
   --  variables, no quadratic term, and one cone of three rows -- a head
   --  row of zeros with lower bound -Radius, so its row of E x less that
   --  bound is Radius, and the identity below it.
   function Disc
     (Q : Vector; Radius : Val; Lo : Val := No_Lower; Hi : Val := No_Upper)
      return Problem;

   --  The root of a half, on the grid: each coordinate of the disc's
   --  answer.
   Root_Half : constant Val := 777_472_127_994;

   --  The answer of Disc ([-One, -One], One): minimize -x1 - x2 with
   --  ||x|| <= 1 is x = (r, r), r the root of a half; the cone's
   --  multipliers are (-2 r, 1, 1): the tail ones balance the objective,
   --  the head one makes their inner product with the rows, (1, r, r),
   --  zero.
   function Disc_Answer return State
   is ((N          => 2,
        K          => 3,
        X | Z      => [Root_Half, Root_Half],
        Y          => [0, 0],
        Z_Row      => [0, Root_Half, Root_Half],
        Y_Row      => [-2 * Root_Half, One, One],
        Iterations => 0));

   --  Two with P given in place of the identity.
   function With_P (Pr : Problem; P : Matrix) return Problem
   with Pre => P'Length (1) = Pr.N and then P'Length (2) = Pr.N;

   --  The tail-mean linear program over Columns columns and Pr.K - 1
   --  seeded scenarios, posed as a caller who knows its data poses it.
   --  Variables: the weights w (each 0 .. 0.05), the threshold a and
   --  the shortfalls u.  Minimize -m'w + a + sum (u) / (0.05 T), m the
   --  columns' means over the T scenarios, subject to r_s'w + a + u_s
   --  >= 0 and sum (w) = 1; a boxed by the range of the scenarios'
   --  losses, each u_s by its largest.  A return is 0.0005 + 0.02 z +
   --  0.01 g, z the column's and g the scenario's normal draw.
   procedure Pose_Tail
     (Pr : out Problem; Columns : Positive; Seed : Interfaces.Unsigned_64)
   with Pre => Pr.N = Columns + Pr.K and then Pr.K >= 2;

   --  Solve from St with S; the outcome.
   function Solved
     (Pr : Problem; S : Settings; St : in out State) return Outcome;

end Abacus_Qp_Problems;
