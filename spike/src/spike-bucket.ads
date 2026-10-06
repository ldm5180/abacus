with Spike.Admm;
with Spike.Estimate;

--  One bucket end to end: returns to z-scores and correlations, the
--  mean-variance problem formed in correlation space, solved by ADMM,
--  and the answer scaled back to weights.

generic
   Frac : Frac_Bits;
package Spike.Bucket with SPARK_Mode is

   package E is new Spike.Estimate (Frac);
   package A is new Spike.Admm (Frac);

   One : constant Raw := 2**Frac;

   --  The problem in the weights w: minimize
   --  (1/2) w'(Lambda S + Ridge I) w - Mean'w, with 0 <= w <= Cap and
   --  each run of Block_Size consecutive assets summing to Budget; S is
   --  the sample covariance.  Ridge, Budget and Cap are raw.
   type Terms is record
      Lambda     : Positive;
      Ridge      : Val;
      Budget     : Val;
      Cap        : Val;
      Block_Size : Index;
   end record;

   --  The S0 bucket's terms: lambda 20, ridge 1e-6, budget 0.10, cap 1,
   --  blocks of 90.
   Default_Terms : constant Terms :=
     (Lambda     => 20,
      Ridge      => (One + 500_000) / 1_000_000,
      Budget     => (One + 5) / 10,
      Cap        => One,
      Block_Size => 90);

   --  The S0 bucket's settings: rho 1, rho_row 2**3, sigma 2**-20,
   --  alpha 1.6, and tolerances of 1e-10 (primal) and 1e-9 (dual) in
   --  correlation space, the values that leave the weights within about
   --  1e-7.  A small rho_row keeps the general rows' duals on a fine
   --  lattice: they move in steps of rho_row units of the grid.
   Default_Settings : constant A.Settings :=
     (Rho_Shift   => 0,
      Row_Shift   => 3,
      Sigma_Shift => -20,
      Alpha       => One * 8 / 5,
      Max_Iter    => 4_000,
      Check_Every => 10,
      Tol_Primal  => One / 10_000_000_000,
      Tol_Dual    => One / 1_000_000_000);

   --  Where a bucket's solve stopped.
   type Stage is (Estimating, Forming, Solving, Done);

   type Bucket_Outcome is record
      Stage      : Bucket.Stage;
      Result     : A.Result_Kind;
      Iterations : Natural;
   end record;

   --  The problem in correlation space, x = sigma w: P = C plus the
   --  ridge over lambda sigma**2, Q = -Mean / (lambda sigma), the box
   --  0 .. Cap sigma, and one row per block, divided through by its
   --  length.  Ok is False when a value leaves its range.
   procedure Form
     (C  : Matrix;
      M  : E.Moments;
      T  : Terms;
      Pr : out A.Problem;
      Ok : out Boolean)
   with
     Pre =>
       C'First (1) = 1
       and then C'Last (1) = Pr.N
       and then C'First (2) = 1
       and then C'Last (2) = Pr.N
       and then M.N = Pr.N
       and then Pr.N mod T.Block_Size = 0
       and then Pr.K = Pr.N / T.Block_Size;

   --  w = x / sigma.
   procedure To_Weights
     (M : E.Moments; X : Vector; W : out Vector; Ok : out Boolean)
   with
     Pre =>
       X'First = 1
       and then X'Last = M.N
       and then W'First = 1
       and then W'Last = M.N;

   --  R holds the returns, one row per asset (z-scores on return); W the
   --  weights when Outcome.Stage is Done.
   procedure Solve_Bucket
     (R       : in out Matrix;
      T       : Terms;
      S       : A.Settings;
      W       : out Vector;
      Outcome : out Bucket_Outcome)
   with
     Pre =>
       R'First (1) = 1
       and then R'First (2) = 1
       and then R'Last (2) >= 2
       and then R'Last (1) >= T.Block_Size
       and then R'Last (1) mod T.Block_Size = 0
       and then W'First = 1
       and then W'Last = R'Last (1);

end Spike.Bucket;
