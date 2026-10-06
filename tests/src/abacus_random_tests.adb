with Interfaces; use Interfaces;

with AUnit.Assertions; use AUnit.Assertions;

with Abacus.Random; use Abacus.Random;

package body Abacus_Random_Tests is

   --  Two generators from one seed give one stream.
   procedure Test_Same_Seed_Same_Stream
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Seed  : constant := 20_261_006;
      Draws : constant := 1_000;
      A, B  : Generator := Seeded (Seed);
      X, Y  : Unsigned_64;
   begin
      for I in 1 .. Draws loop
         Next (A, X);
         Next (B, Y);
         Assert (X = Y, "draw" & I'Image);
      end loop;
   end Test_Same_Seed_Same_Stream;

   --  SplitMix64's published stream for the seed 1234567.
   procedure Test_Reference (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Seed   : constant := 1_234_567;
      First  : constant := 6_457_827_717_110_365_317;
      Second : constant := 3_203_168_211_198_807_973;
      Third  : constant := 9_817_491_932_198_370_423;
      G      : Generator := Seeded (Seed);
      X      : Unsigned_64;
   begin
      Next (G, X);
      Assert (X = First, "first");
      Next (G, X);
      Assert (X = Second, "second");
      Next (G, X);
      Assert (X = Third, "third");
   end Test_Reference;

   --  Below (N) stays below N, reaches every value, and is even: each of
   --  ten values comes up within 5% of a tenth of 100,000 draws.
   procedure Test_Below (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Draws  : constant := 100_000;
      Slack  : constant := 500;
      G      : Generator := Seeded (7);
      Counts : array (Unsigned_64 range 0 .. 9) of Natural := [others => 0];
      X      : Unsigned_64;
   begin
      for I in 1 .. Draws loop
         Below (G, 10, X);
         Assert (X < 10, "below ten");
         Counts (X) := Counts (X) + 1;
      end loop;
      for C of Counts loop
         Assert (abs (C - Draws / 10) <= Slack, "even:" & C'Image);
      end loop;
      Below (G, 1, X);
      Assert (X = 0, "below one is zero");
      Below (G, Unsigned_64'Last, X);
      Assert (X < Unsigned_64'Last, "below the largest");
   end Test_Below;

   overriding
   procedure Register_Tests (T : in out Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T, Test_Same_Seed_Same_Stream'Access, "One seed, one stream");
      Register_Routine (T, Test_Reference'Access, "SplitMix64's stream");
      Register_Routine (T, Test_Below'Access, "Below, without bias");
   end Register_Tests;

   overriding
   function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("Abacus.Random");
   end Name;

end Abacus_Random_Tests;
