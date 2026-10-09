--  The problem with a set of its bounds held: the bounds read off an
--  iterate, and the problem solved with them held as equalities for a
--  cost given -- each held variable at its bound, the free variables from
--  the equality-constrained problem, the held rows' multipliers by least
--  squares and the held variables' from the gradient.  The solves go
--  through the Cholesky factorization of the held rows' regularized
--  systems, refined against the exact one finer than the grid.  The
--  polish and the crossover both work on it.

package Abacus.Qp.Held
  with SPARK_Mode
is

   --  The side a constraint at Z with multiplier Y holds in [Lo, Hi].
   function Side_Of (Z, Y, Lo, Hi : Val) return Side
   is (if Lo = Hi
       then At_Lower
       elsif Lo /= No_Lower and then Wide (Z) - Wide (Lo) < -Wide (Y)
       then At_Lower
       elsif Hi /= No_Upper and then Wide (Hi) - Wide (Z) < Wide (Y)
       then At_Upper
       else Free);

   --  The bound a held side names.
   function Bound_Of (S : Side; Lo, Hi : Val) return Val
   is (if S = At_Upper then Hi else Lo);

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

   --  Work's sides read off St, OSQP's rule: a bound is held when the
   --  constraint lies nearer to it than its multiplier pulls toward it.
   --  An equality row is always held; an open bound never, nor a cone's
   --  row.
   procedure Read_Held (Pr : Problem; St : State; Work : in out Workspace)
   with Pre => Fits_Work (Pr, Work) and then Fits_State (Pr, St);

   --  Whether variable I is free, and whether general row R is held.
   function Is_Free (Work : Workspace; I : Index) return Boolean
   is (Work.Box_Side (I) = Free)
   with Pre => I <= Work.N;

   function Is_Held_Row (Work : Workspace; R : Index) return Boolean
   is (Work.Row_Side (R) /= Free)
   with Pre => R <= Work.K;

   --  Whether Work's maps name places of Pr.
   function Packed (Pr : Problem; Work : Workspace) return Boolean
   is (Fits_Work (Pr, Work)
       and then Work.Free_Count <= Pr.N
       and then Work.Row_Count <= Pr.K
       and then (for all Q in 1 .. Work.Free_Count => Work.Free_At (Q) <= Pr.N)
       and then (for all P in 1 .. Work.Row_Count => Work.Row_At (P) <= Pr.K));

   --  The problem, its linear term Cost in place of Q, solved with Work's
   --  sides held, from Cand: Cand becomes the answer and its
   --  multipliers.  Ok is False when a value left its range or a
   --  factorization was refused.
   procedure Solve
     (Pr   : Problem;
      Cost : Vector;
      Work : in out Workspace;
      Cand : in out State;
      Ok   : out Boolean)
   with
     Pre =>
       Fits_Work (Pr, Work)
       and then Fits_State (Pr, Cand)
       and then Cost'First = 1
       and then Cost'Last = Pr.N;

   --  Z over the free variables, packed, solving A Z = V over the held
   --  rows, packed: A the held rows over the free columns as the last
   --  Solve packed them and A A' as it factored it.  Z = A'(A A')**-1 V,
   --  refined against the exact system, so exact for a square A.  Ok is
   --  False when a value left its range.
   procedure Direction
     (Pr   : Problem;
      Work : Workspace;
      V    : Vector;
      Z    : out Vector;
      Ok   : out Boolean)
   with
     Pre =>
       Packed (Pr, Work)
       and then V'First = 1
       and then V'Last = Pr.K
       and then Z'First = 1
       and then Z'Last = Pr.N;

   --  W over the held rows solving A'W = C over the free variables, both
   --  packed, likewise: least squares through A A', refined.
   procedure Prices
     (Pr   : Problem;
      Work : Workspace;
      C    : Vector;
      W    : out Vector;
      Ok   : out Boolean)
   with
     Pre =>
       Packed (Pr, Work)
       and then C'First = 1
       and then C'Last = Pr.N
       and then W'First = 1
       and then W'Last = Pr.K;

   --  Where Work's held set is not a basis: the first held row, packed
   --  with the equalities first, that depends on those before it over the
   --  free columns, or failing one the first free column that depends on
   --  those before it; zero for neither.
   type Dependence is record
      Row    : Count := 0;
      Column : Count := 0;
   end record;

   --  Work's held set packed, and its dependence found through A A' and
   --  A'A factored with a floor.  Ok is False when a value left its range.
   procedure Find_Dependence
     (Pr    : Problem;
      Work  : in out Workspace;
      Found : out Dependence;
      Ok    : out Boolean)
   with Pre => Fits_Work (Pr, Work), Post => Packed (Pr, Work);

   --  The vertex Work's held set names when it is a basis, for a cost
   --  given: each held variable at its bound, the free ones from the held
   --  rows, A x = b, and the rows' multipliers from A'lambda = -(P x +
   --  Cost) over the free columns, both through A A' with no more ridge
   --  than refuses a zero pivot, and refined.  Ok is False when a value
   --  left its range or the factorization was refused.
   procedure Solve_Vertex
     (Pr   : Problem;
      Cost : Vector;
      Work : in out Workspace;
      Cand : in out State;
      Ok   : out Boolean)
   with
     Pre  =>
       Fits_Work (Pr, Work)
       and then Fits_State (Pr, Cand)
       and then Cost'First = 1
       and then Cost'Last = Pr.N,
     Post => Packed (Pr, Work);

end Abacus.Qp.Held;
