with Interfaces; use Interfaces;

with AUnit.Assertions; use AUnit.Assertions;

with Abacus;         use Abacus;
with Abacus.Vectors; use Abacus.Vectors;

package body Abacus_Vectors_Tests is

   --  A seeded vector of N values within Bound, from Knuth's MMIX
   --  generator, for tests that need many elements.
   Multiplier : constant := 6_364_136_223_846_793_005;
   Increment  : constant := 1_442_695_040_888_963_407;

   function Seeded (N : Index; Seed : Unsigned_64; Bound : Val) return Vector
   is
      S      : Unsigned_64 := Seed;
      Result : Vector (1 .. N);
   begin
      for I in Result'Range loop
         S := S * Multiplier + Increment;
         Result (I) := Val (Raw (S / 2**7) mod (2 * Bound + 1) - Bound);
      end loop;
      return Result;
   end Seeded;

   function Reversed (V : Vector) return Vector is
      Result : Vector (V'Range);
   begin
      for I in V'Range loop
         Result (V'Last - I + V'First) := V (I);
      end loop;
      return Result;
   end Reversed;

   Long : constant := 4_096;

   --  A dot product, and the same with both vectors reversed, are equal
   --  exactly: the sum is exact and rounded once.
   procedure Test_Dot_Is_Order_Free
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      A : constant Vector := Seeded (Long, 1, Val'Last);
      B : constant Vector := Seeded (Long, 2, Val'Last);
   begin
      Assert (Dot (A, B) = Dot (Reversed (A), Reversed (B)), "reversed");
      Assert (Dot (A, B) = Dot (A => B, B => A), "swapped");
      Assert (Sum (A) = Sum (Reversed (A)), "a sum, reversed");
   end Test_Dot_Is_Order_Free;

   --  A dot product rounds once, not once per term: three products of a
   --  third of a unit each sum to one unit.
   procedure Test_Rounds_Once (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Third : constant Val := One / 3;
      Unit  : constant Vector (1 .. 3) := [1, 1, 1];
   begin
      Assert (Dot (Unit, [Third, Third, Third]) = 1, "a unit of thirds");
      Assert (Dot (Unit, [One, One, One]) = 3, "three units");
      Assert (Dot ([One / 2, One / 2], [1, 1]) = 1, "two halves of a unit");
      Assert (Dot_Exact ([2, 3], [5, 7]) = 31, "exact at One * One");
      Assert (Dot (Vector'(1 .. 0 => 0), Vector'(1 .. 0 => 0)) = 0, "empty");
      Assert
        (Dot ([Val'Last, Val'Last], [Val'Last, Val'Last]) = 2 * 2**74,
         "the largest terms");
   end Test_Rounds_Once;

   --  Sums are exact; the norm is the largest magnitude.
   procedure Test_Sum_And_Norm (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Assert (Sum ([1, 2, 3]) = 6, "a sum");
      Assert
        (Sum ([Val'Last, Val'Last]) = 2 * Wide (Val'Last), "past a value");
      Assert (Sum (Vector'(1 .. 0 => 0)) = 0, "an empty sum");
      Assert (Norm_Inf ([3, -7, 5]) = 7, "the largest magnitude");
      Assert (Norm_Inf ([Val'First]) = Val'Last, "the smallest value");
      Assert (Norm_Inf (Vector'(1 .. 0 => 0)) = 0, "an empty norm");
   end Test_Sum_And_Norm;

   --  Axpy and scaling store through the checked store.
   procedure Test_Axpy (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Y  : Vector (1 .. 2) := [One, 2 * One];
      Ok : Boolean;
   begin
      Axpy (One / 2, [2 * One, 4 * One], Y, Ok);
      Assert (Ok and then Y = [2 * One, 4 * One], "y + x / 2");
      Axpy (Val'Last, [One, 0], Y, Ok);
      Assert (not Ok and then Y = [2 * One, 4 * One], "past the values");
      Scale (-One, Y, Ok);
      Assert (Ok and then Y = [-2 * One, -4 * One], "negated");
      Scale (Val'Last, Y, Ok);
      Assert (not Ok and then Y = [-2 * One, -4 * One], "scaled too far");
   end Test_Axpy;

   overriding
   procedure Register_Tests (T : in out Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T, Test_Dot_Is_Order_Free'Access, "A dot product is order-free");
      Register_Routine
        (T, Test_Rounds_Once'Access, "A dot product rounds once");
      Register_Routine (T, Test_Sum_And_Norm'Access, "Sums and the norm");
      Register_Routine (T, Test_Axpy'Access, "Axpy and scaling");
   end Register_Tests;

   overriding
   function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("Abacus.Vectors");
   end Name;

end Abacus_Vectors_Tests;
