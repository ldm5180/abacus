with Spike.Grid;
with Spike.Kernels; use Spike.Kernels;

package body Spike.Bucket
  with SPARK_Mode
is

   package G is new Spike.Grid (Frac);

   use type E.Estimate_Result;
   use type A.Result_Kind;

   function Mul (A, B : Val) return Wide renames G.Mul;

   --  P = C + the ridge in correlation space, Ridge / (Lambda sigma**2);
   --  Q = -Mean / (Lambda sigma).
   procedure Form_Objective
     (C  : Matrix;
      M  : E.Moments;
      T  : Terms;
      Pr : in out A.Problem;
      Ok : in out Boolean)
   with
     Pre =>
       C'First (1) = 1
       and then C'Last (1) = Pr.N
       and then C'First (2) = 1
       and then C'Last (2) = Pr.N
       and then M.N = Pr.N
   is
      Scaled : Val := 0;
   begin
      Pr.P := C;
      for I in 1 .. Pr.N loop
         Store (Mul (T.Ridge, M.Inv_Sigma (I)), Scaled, Ok);
         Store (Mul (Scaled, M.Inv_Sigma (I)), Scaled, Ok);
         Store
           (Wide (C (I, I)) + Div_Round (Wide (Scaled), Wide (T.Lambda)),
            Pr.P (I, I),
            Ok);
         Store (Mul (M.Mean (I), M.Inv_Sigma (I)), Scaled, Ok);
         Store (-Div_Round (Wide (Scaled), Wide (T.Lambda)), Pr.Q (I), Ok);
      end loop;
   end Form_Objective;

   --  x <= Cap sigma, with x = sigma w; Form has set Lo to zero.
   procedure Form_Box
     (M : E.Moments; T : Terms; Pr : in out A.Problem; Ok : in out Boolean)
   with Pre => M.N = Pr.N
   is
   begin
      for I in 1 .. Pr.N loop
         if M.Inv_Sigma (I) < 1 then
            Ok := False;
         else
            Store
              (Div_Round (Wide (T.Cap) * G.One, Wide (M.Inv_Sigma (I))),
               Pr.Hi (I),
               Ok);
         end if;
      end loop;
   end Form_Box;

   --  Block B's row: the sum of x / sigma over the block equals Budget,
   --  divided through by the row's length so its entries are small.
   procedure Form_Row
     (M  : E.Moments;
      T  : Terms;
      B  : Index;
      Pr : in out A.Problem;
      Ok : in out Boolean)
   with
     Pre =>
       M.N = Pr.N
       and then B <= Pr.K
       and then Pr.N mod T.Block_Size = 0
       and then B * T.Block_Size <= Pr.N
   is
      First  : constant Index := (B - 1) * T.Block_Size + 1;
      Last   : constant Index := B * T.Block_Size;
      Square : Wide := 0;
      Norm   : Val;
   begin
      for I in First .. Last loop
         Square := Square + Wide (M.Inv_Sigma (I)) * Wide (M.Inv_Sigma (I));
         exit when Square >= Term_Bound;
         pragma Loop_Invariant (Square in 0 .. Term_Bound - 1);
      end loop;
      Norm := (if Square in Root_Arg then Root (Square) else 0);
      if Norm < 1 then
         Ok := False;
         return;
      end if;
      for I in First .. Last loop
         Store
           (Div_Round (Wide (M.Inv_Sigma (I)) * G.One, Wide (Norm)),
            Pr.E (B, I),
            Ok);
      end loop;
      Store
        (Div_Round (Wide (T.Budget) * G.One, Wide (Norm)), Pr.Row_Lo (B), Ok);
      Pr.Row_Hi (B) := Pr.Row_Lo (B);
   end Form_Row;

   procedure Form
     (C  : Matrix;
      M  : E.Moments;
      T  : Terms;
      Pr : out A.Problem;
      Ok : out Boolean) is
   begin
      Ok := True;
      Pr.P := [others => [others => 0]];
      Pr.Q := [others => 0];
      Pr.Lo := [others => 0];
      Pr.Hi := [others => 0];
      Pr.E := [others => [others => 0]];
      Pr.Row_Lo := [others => 0];
      Pr.Row_Hi := [others => 0];
      Form_Objective (C, M, T, Pr, Ok);
      Form_Box (M, T, Pr, Ok);
      for B in 1 .. Pr.K loop
         Form_Row (M, T, B, Pr, Ok);
      end loop;
   end Form;

   procedure To_Weights
     (M : E.Moments; X : Vector; W : out Vector; Ok : out Boolean) is
   begin
      W := [others => 0];
      Ok := True;
      for I in W'Range loop
         Store (Mul (X (I), M.Inv_Sigma (I)), W (I), Ok);
      end loop;
   end To_Weights;

   procedure Solve_Bucket
     (R       : in out Matrix;
      T       : Terms;
      S       : A.Settings;
      W       : out Vector;
      Outcome : out Bucket_Outcome)
   is
      N   : constant Index := R'Last (1);
      K   : constant Count := N / T.Block_Size;
      M   : E.Moments (N);
      C   : Matrix (1 .. N, 1 .. N) := [others => [others => 0]];
      Pr  : A.Problem (N, K);
      St  : A.State := A.Cold (N, K);
      Est : E.Estimate_Outcome;
      Ok  : Boolean;
   begin
      W := [others => 0];
      Outcome := (Estimating, A.Exhausted, 0);
      E.Standardize (R, M, Est);
      if Est.Result = E.Estimated then
         E.Correlate (R, C, Est);
      end if;
      if Est.Result /= E.Estimated then
         return;
      end if;
      Outcome.Stage := Forming;
      Form (C, M, T, Pr, Ok);
      if not Ok then
         return;
      end if;
      Outcome.Stage := Solving;
      A.Solve (Pr, S, St, Outcome.Result);
      Outcome.Iterations := St.Iterations;
      if Outcome.Result in A.Converged | A.Stalled | A.Exhausted then
         To_Weights (M, St.X, W, Ok);
         Outcome.Stage := (if Ok then Done else Solving);
      end if;
   end Solve_Bucket;

end Spike.Bucket;
