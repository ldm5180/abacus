with Interfaces; use Interfaces;

with Abacus.Random; use Abacus.Random;

package body Bench_Data is

   Seed    : constant := 20_261_006;
   Factors : constant := 5;

   --  A draw in -Bound .. Bound.
   function Draw (G : in out Generator; Bound : Val) return Val is
      X : Unsigned_64;
   begin
      Next (G, X);
      return Val (Raw (X / 2**7) mod (2 * Bound + 1) - Bound);
   end Draw;

   function Returns (N : Index; Days : Positive) return Matrix_Access is
      G      : Generator := Seeded (Seed);
      Result : constant Matrix_Access := new Matrix (1 .. N, 1 .. Days);
   begin
      for I in 1 .. N loop
         for T in 1 .. Days loop
            Result (I, T) := Draw (G, One / 20);
         end loop;
      end loop;
      return Result;
   end Returns;

   type Loadings is array (Positive range <>, Positive range <>) of Val;

   --  Each series' loading on each factor, its squares summing under
   --  0.9, so the idiosyncratic part tops the diagonal up to one.
   function Load (N : Index) return Loadings is
      G      : Generator := Seeded (Seed + 1);
      Result : Loadings (1 .. N, 1 .. Factors);
   begin
      for I in 1 .. N loop
         for K in 1 .. Factors loop
            Result (I, K) := Draw (G, 2 * One / 5);
         end loop;
      end loop;
      return Result;
   end Load;

   function Entry_Of (B : Loadings; I, J : Index) return Val is
      Sum : Wide := 0;
   begin
      for K in 1 .. Factors loop
         Sum := Sum + Wide (B (I, K)) * Wide (B (J, K));
      end loop;
      return Val (Sum / One);
   end Entry_Of;

   function Correlation (N : Index) return Matrix_Access is
      B      : constant Loadings := Load (N);
      Result : constant Matrix_Access := new Matrix (1 .. N, 1 .. N);
   begin
      for I in 1 .. N loop
         for J in 1 .. N loop
            Result (I, J) := (if I = J then One else Entry_Of (B, I, J));
         end loop;
      end loop;
      return Result;
   end Correlation;

   function Program (N : Index) return Problem_Access is
      C      : constant Matrix_Access := Correlation (N);
      G      : Generator := Seeded (Seed + 2);
      Result : constant Problem_Access := new Problem (N, 1);
   begin
      Result.P := C.all;
      for I in 1 .. N loop
         Result.Q (I) := -Draw (G, One / 10) - One / 10;
      end loop;
      Result.Lo := [others => 0];
      Result.Hi := [others => One / 20];
      Result.E := [others => [others => One]];
      Result.Row_Lo := [One];
      Result.Row_Hi := [One];
      return Result;
   end Program;

end Bench_Data;
