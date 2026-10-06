with Ada.Real_Time; use Ada.Real_Time;
with Ada.Text_IO;   use Ada.Text_IO;
with Bench_Report;  use Bench_Report;
with Fixtures;

package body Bench_Bucket is

   use type B.E.Estimate_Result;
   use type B.A.Prepare_Result;

   N : constant := Fixtures.Assets;
   K : constant := N / Fixtures.Block;

   type Matrix_Access is access Matrix;

   Returns : constant Matrix_Access := new Matrix'(Fixtures.Returns (Frac));
   Oracle  : constant Vector := Fixtures.Weights (Frac);

   --  The largest distance of the weights of St from the oracle's, raw.
   function Distance (M : B.E.Moments; St : B.A.State) return Raw is
      W  : Vector (1 .. N);
      Ok : Boolean;
      D  : Raw := 0;
   begin
      B.To_Weights (M, St.X, W, Ok);
      for I in W'Range loop
         D := Raw'Max (D, abs (W (I) - Oracle (I)));
      end loop;
      return (if Ok then D else Raw'Last);
   end Distance;

   procedure Trace (S : B.A.Settings; Label : String) is
      R      : constant Matrix_Access := new Matrix'(Returns.all);
      C      : constant Matrix_Access := new Matrix (1 .. N, 1 .. N);
      M      : B.E.Moments (N);
      Est    : B.E.Estimate_Outcome;
      Pr     : B.A.Problem (N, K);
      F      : B.A.Factored (N);
      St     : B.A.State := B.A.Cold (N, K);
      Setup  : B.A.Prepare_Result;
      Ok     : Boolean;
      Res    : B.A.Residual;
      D      : Raw;
      Within : constant Raw := 2**Frac / 1_000_000;
      First  : Natural := 0;
      Stop   : Natural := 0;
   begin
      B.E.Standardize (R.all, M, Est);
      B.E.Correlate (R.all, C.all, Est);
      B.Form (C.all, M, B.Default_Terms, Pr, Ok);
      B.A.Prepare (Pr, S, F, Setup);
      pragma
        Assert
          (Est.Result = B.E.Estimated and then Ok and then Setup = B.A.Ready);
      for It in 1 .. S.Max_Iter loop
         B.A.Iterate (Pr, S, F, St, Ok);
         exit when not Ok;
         if It mod S.Check_Every = 0 then
            Res := B.A.Residuals (Pr, St);
            D := Distance (M, St);
            if First = 0 and then D <= Within then
               First := It;
               Put_Line
                 ("trace,"
                  & Label
                  & ","
                  & Frac'Image
                  & ", within 1e-6 at"
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
               Put_Line
                 ("trace,"
                  & Label
                  & ","
                  & Frac'Image
                  & ", rule stops at"
                  & It'Image
                  & ", distance"
                  & D'Image
                  & " raw ="
                  & Duration'Image
                      (Duration (D) / 2**(Frac - 30) / 1_073_741_824));
            end if;
         end if;
      end loop;
      Put_Line
        ("trace,"
         & Label
         & ","
         & Frac'Image
         & ", first within 1e-6 at"
         & First'Image
         & ", after"
         & S.Max_Iter'Image
         & ": distance"
         & D'Image
         & " raw, primal"
         & Res.Primal'Image
         & ", dual"
         & Res.Dual'Image
         & ", ok "
         & Ok'Image);
   end Trace;

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
