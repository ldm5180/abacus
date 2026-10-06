with Ada.Real_Time; use Ada.Real_Time;
with Ada.Text_IO;   use Ada.Text_IO;
with Bench_Report;  use Bench_Report;
with Fixtures;
with Spike.Grid;

package body Bench_Bucket is

   use type B.E.Estimate_Result;
   use type B.A.Prepare_Result;

   package G is new Spike.Grid (Frac);

   N : constant := Fixtures.Assets;
   K : constant := N / Fixtures.Block;

   One : constant Raw := 2**Frac;

   type Matrix_Access is access Matrix;
   type Problem_Access is access B.A.Problem;

   Returns : constant Matrix_Access := new Matrix'(Fixtures.Returns (Frac));
   Oracle  : constant Vector := Fixtures.Weights (Frac);

   function Image (Raw_Value : Raw) return String
   is (Duration'Image (Duration (Raw_Value) / 2**(Frac - 30) / 1_073_741_824));

   --  The z-scores' correlation and the moments of the bucket.
   procedure Estimate (C : out Matrix; M : out B.E.Moments) is
      R   : constant Matrix_Access := new Matrix'(Returns.all);
      Est : B.E.Estimate_Outcome;
   begin
      B.E.Standardize (R.all, M, Est);
      B.E.Correlate (R.all, C, Est);
      pragma Assert (Est.Result = B.E.Estimated);
   end Estimate;

   --  The same problem in the weights themselves: P = lambda S + ridge
   --  I with S rebuilt from the correlation and the deviations, Q the
   --  negated means, the box 0 .. Cap, and each block's row of ones.
   procedure Form_Unscaled (C : Matrix; M : B.E.Moments; Pr : out B.A.Problem)
   is
      T : constant B.Terms := B.Default_Terms;
   begin
      for I in 1 .. N loop
         for J in 1 .. N loop
            Pr.P (I, J) :=
              Val
                (G.Round
                   (Wide (Val (G.Mul (C (I, J), M.Sigma (I))))
                    * Wide (M.Sigma (J))))
              * Raw (T.Lambda)
              + (if I = J then T.Ridge else 0);
         end loop;
         Pr.Q (I) := -M.Mean (I);
         Pr.Lo (I) := 0;
         Pr.Hi (I) := T.Cap;
         for R in 1 .. K loop
            Pr.E (R, I) := (if (I - 1) / T.Block_Size + 1 = R then One else 0);
         end loop;
      end loop;
      Pr.Row_Lo := [others => T.Budget];
      Pr.Row_Hi := [others => T.Budget];
   end Form_Unscaled;

   --  The largest distance of St's weights from the oracle's, raw.
   function Distance
     (M : B.E.Moments; St : B.A.State; Scaled : Boolean) return Raw
   is
      W  : Vector (1 .. N);
      Ok : Boolean := True;
      D  : Raw := 0;
   begin
      if Scaled then
         B.To_Weights (M, St.X, W, Ok);
      else
         W := St.X;
      end if;
      for I in W'Range loop
         D := Raw'Max (D, abs (W (I) - Oracle (I)));
      end loop;
      return (if Ok then D else Raw'Last);
   end Distance;

   procedure Say (Label, What : String) is
   begin
      Put_Line ("trace," & Label & "," & Frac'Image & ", " & What);
   end Say;

   procedure Trace_Problem
     (Pr     : B.A.Problem;
      M      : B.E.Moments;
      Scaled : Boolean;
      S      : B.A.Settings;
      Label  : String)
   is
      F     : B.A.Factored (N);
      St    : B.A.State := B.A.Cold (N, K);
      Setup : B.A.Prepare_Result;
      Ok    : Boolean;
      Res   : B.A.Residual := (0, 0);
      D     : Raw := Raw'Last;
      First : Natural := 0;
      Stop  : Natural := 0;
   begin
      B.A.Prepare (Pr, S, F, Setup);
      if Setup /= B.A.Ready then
         Say (Label, "prepare " & Setup'Image);
         return;
      end if;
      for It in 1 .. S.Max_Iter loop
         B.A.Iterate (Pr, S, F, St, Ok);
         exit when not Ok;
         if It mod S.Check_Every = 0 then
            Res := B.A.Residuals (Pr, St);
            D := Distance (M, St, Scaled);
            if First = 0 and then D <= One / 1_000_000 then
               First := It;
               Say
                 (Label,
                  "within 1e-6 at"
                  & It'Image
                  & ": primal"
                  & Res.Primal'Image
                  & ", dual"
                  & Res.Dual'Image);
            end if;
            if Stop = 0
              and then Res.Primal <= Wide (S.Tol_Primal)
              and then Res.Dual <= Wide (S.Tol_Dual)
            then
               Stop := It;
               Say
                 (Label,
                  "rule stops at" & It'Image & ", distance" & Image (D));
            end if;
         end if;
      end loop;
      Say
        (Label,
         "after"
         & St.Iterations'Image
         & ": distance"
         & D'Image
         & " raw ="
         & Image (D)
         & ", primal"
         & Res.Primal'Image
         & ", dual"
         & Res.Dual'Image
         & ", ok "
         & Ok'Image);
   end Trace_Problem;

   procedure Trace (S : B.A.Settings; Label : String; Scaled : Boolean := True)
   is
      C  : constant Matrix_Access := new Matrix (1 .. N, 1 .. N);
      M  : B.E.Moments (N);
      Pr : constant Problem_Access := new B.A.Problem (N, K);
      Ok : Boolean;
   begin
      Estimate (C.all, M);
      if Scaled then
         B.Form (C.all, M, B.Default_Terms, Pr.all, Ok);
      else
         Form_Unscaled (C.all, M, Pr.all);
      end if;
      Trace_Problem
        (Pr.all,
         M,
         Scaled,
         S,
         Label & (if Scaled then " scaled" else " unscaled"));
   end Trace;

   procedure Time_Stages (S : B.A.Settings; Runs : Positive) is
      C      : constant Matrix_Access := new Matrix (1 .. N, 1 .. N);
      M      : B.E.Moments (N);
      Pr     : constant Problem_Access := new B.A.Problem (N, K);
      F      : B.A.Factored (N);
      St     : B.A.State := B.A.Cold (N, K);
      Setup  : B.A.Prepare_Result;
      Ok     : Boolean;
      Result : B.A.Result_Kind;
      Start  : Time;
      Best   : array (1 .. 3) of Time_Span := [others => Time_Span_Last];
   begin
      for Run in 1 .. Runs loop
         Start := Clock;
         Estimate (C.all, M);
         Best (1) :=
           (if Clock - Start < Best (1) then Clock - Start else Best (1));
         Start := Clock;
         B.Form (C.all, M, B.Default_Terms, Pr.all, Ok);
         B.A.Prepare (Pr.all, S, F, Setup);
         Best (2) :=
           (if Clock - Start < Best (2) then Clock - Start else Best (2));
         St := B.A.Cold (N, K);
         Start := Clock;
         B.A.Solve (Pr.all, S, St, Result);
         Best (3) :=
           (if Clock - Start < Best (3) then Clock - Start else Best (3));
      end loop;
      Report ("stage estimate", Frac, N, Best (1));
      Report ("stage form and factor", Frac, N, Best (2));
      Report
        ("stage solve, its own factor included, "
         & Result'Image
         & St.Iterations'Image
         & " iterations",
         Frac,
         N,
         Best (3));

   end Time_Stages;

   procedure Time_Bucket (S : B.A.Settings; Runs : Positive) is
      R       : constant Matrix_Access :=
        new Matrix (1 .. N, 1 .. Fixtures.Days);
      W       : Vector (1 .. N);
      Outcome : B.Bucket_Outcome;
      Start   : Time;
      Best    : Time_Span := Time_Span_Last;
   begin
      for Run in 1 .. Runs loop
         R.all := Returns.all;
         Start := Clock;
         B.Solve_Bucket (R.all, B.Default_Terms, S, W, Outcome);
         if Clock - Start < Best then
            Best := Clock - Start;
         end if;
      end loop;
      Report
        ("bucket "
         & Outcome.Stage'Image
         & " "
         & Outcome.Result'Image
         & Outcome.Iterations'Image
         & " iterations",
         Frac,
         N,
         Best);
      Sink := Sink + Wide (W (1));
   end Time_Bucket;

end Bench_Bucket;
