with Interfaces;

--  A seeded 64-bit generator, SplitMix64, in modular arithmetic with its
--  state explicit: one seed gives one stream, on every machine.  Below
--  draws an integer under a bound without bias, by rejection.

package Abacus.Random
  with SPARK_Mode, Pure
is

   use type Interfaces.Unsigned_64;

   type Generator is private;

   function Seeded (Seed : Interfaces.Unsigned_64) return Generator;

   --  The next 64 bits of the stream.
   procedure Next (G : in out Generator; X : out Interfaces.Unsigned_64);

   --  An integer in 0 .. N - 1, each equally likely: a draw past the
   --  last whole multiple of N below 2**64 is drawn again.  The redraws
   --  are capped at Max_Redraws, past which the odds are below 2**-128;
   --  the cap only makes the loop's end a fact.
   Max_Redraws : constant := 128;

   procedure Below
     (G : in out Generator;
      N : Interfaces.Unsigned_64;
      X : out Interfaces.Unsigned_64)
   with Pre => N >= 1, Post => X < N;

private

   type Generator is record
      State : Interfaces.Unsigned_64 := 0;
   end record;

   function Seeded (Seed : Interfaces.Unsigned_64) return Generator
   is ((State => Seed));

end Abacus.Random;
