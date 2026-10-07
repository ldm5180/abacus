with AUnit.Assertions; use AUnit.Assertions;

with Abacus;          use Abacus;
with Abacus.Qp.Cones; use Abacus.Qp.Cones;

package body Abacus_Qp_Cones_Tests is

   --  (0, 3, 4) lies outside the cone and above its polar: it projects
   --  onto the boundary at ((0 + 5) / 2, (3, 4) times 5 / 10).
   procedure Test_Projects_To_Boundary
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      V  : Vector := [0, 3 * One, 4 * One];
      Ok : Boolean := True;
   begin
      Project (V, 1, 3, Ok);
      Assert (Ok, "in range");
      Assert (V = [5 * One / 2, 3 * One / 2, 2 * One], "on the boundary");
   end Test_Projects_To_Boundary;

   --  A point inside the cone is kept; one inside its polar becomes
   --  zero; a cone of one row is the half line s >= 0.
   procedure Test_Inside_And_Polar
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Inside : Vector := [5 * One, 3 * One, 4 * One];
      Polar  : Vector := [-5 * One, 3 * One, 4 * One];
      Half   : Vector := [-2 * One, 7 * One];
      Ok     : Boolean := True;
   begin
      Project (Inside, 1, 3, Ok);
      Assert (Inside = [5 * One, 3 * One, 4 * One], "inside, kept");
      Project (Polar, 1, 3, Ok);
      Assert (Polar = [0, 0, 0], "in the polar, zero");
      Project (Half, 1, 1, Ok);
      Assert (Half = [0, 7 * One], "a negative head alone becomes zero");
      Project (Half, 2, 2, Ok);
      Assert (Half = [0, 7 * One], "a positive one is kept");
      Assert (Ok, "in range");
   end Test_Inside_And_Polar;

   --  Only the run moves: the entries either side are left.
   procedure Test_Run_Only (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      V  : Vector := [9, 0, 3 * One, 4 * One, -9];
      Ok : Boolean := True;
   begin
      Project (V, 2, 4, Ok);
      Assert (V = [9, 5 * One / 2, 3 * One / 2, 2 * One, -9], "the run");
   end Test_Run_Only;

   --  The norm rounds to nearest: that of (1, 1) is the grid's root of 2.
   procedure Test_Norm (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Root_2 : constant := 1_554_944_255_988;
      V      : constant Vector := [One, One, 0];
      R      : constant Norm_Result := Norm (V, 1, 2);
   begin
      Assert (R.Fits and then R.Value = Root_2, R.Value'Image);
      Assert (Norm (V, 3, 2) = (True, 0), "an empty span");
   end Test_Norm;

   --  A norm past the values clears Ok and leaves the run, and counts as
   --  beyond every tolerance.
   procedure Test_Too_Large (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      V  : Vector := [0, Val'Last, Val'Last];
      Ok : Boolean := True;
   begin
      Assert (not Norm (V, 2, 3).Fits, "not a value");
      Project (V, 1, 3, Ok);
      Assert (not Ok and then V = [0, Val'Last, Val'Last], "refused, kept");
      Assert (Excess (V, 1, 3) = Beyond, "excess beyond");
      Assert (Polar_Excess (V, 1, 3) = Beyond, "polar excess beyond");
   end Test_Too_Large;

   --  How far a point lies outside the cone and outside its polar.
   procedure Test_Excess (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Out_Of_Both : constant Vector := [0, 3 * One, 4 * One];
      Inside      : constant Vector := [5 * One, 3 * One, 4 * One];
      In_Polar    : constant Vector := [-6 * One, 3 * One, 4 * One];
   begin
      Assert (Excess (Out_Of_Both, 1, 3) = 5 * One, "outside the cone");
      Assert (Polar_Excess (Out_Of_Both, 1, 3) = 5 * One, "outside the polar");
      Assert (Excess (Inside, 1, 3) = 0, "inside the cone");
      Assert (Polar_Excess (Inside, 1, 3) = 10 * One, "far from the polar");
      Assert (Polar_Excess (In_Polar, 1, 3) = 0, "inside the polar");
      Assert (Excess (In_Polar, 1, 3) = 11 * One, "far from the cone");
   end Test_Excess;

   --  The projection onto the polar mirrors the one onto the cone.
   procedure Test_Project_Polar (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Outside  : Vector := [0, 3 * One, 4 * One];
      In_Polar : Vector := [-5 * One, 3 * One, 4 * One];
      In_Cone  : Vector := [5 * One, 3 * One, 4 * One];
      Ok       : Boolean := True;
   begin
      Project_Polar (Outside, 1, 3, Ok);
      Assert
        (Outside = [-5 * One / 2, 3 * One / 2, 2 * One], "to the boundary");
      Project_Polar (In_Polar, 1, 3, Ok);
      Assert (In_Polar = [-5 * One, 3 * One, 4 * One], "kept");
      Project_Polar (In_Cone, 1, 3, Ok);
      Assert (In_Cone = [0, 0, 0], "zero");
      Assert (Ok, "in range");
   end Test_Project_Polar;

   overriding
   procedure Register_Tests (T : in out Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine
        (T,
         Test_Projects_To_Boundary'Access,
         "A point outside projects onto the boundary");
      Register_Routine
        (T, Test_Inside_And_Polar'Access, "Inside kept, the polar zero");
      Register_Routine (T, Test_Run_Only'Access, "Only the run moves");
      Register_Routine (T, Test_Norm'Access, "The norm, rounded to nearest");
      Register_Routine
        (T, Test_Too_Large'Access, "A norm past the values is refused");
      Register_Routine (T, Test_Excess'Access, "How far outside");
      Register_Routine
        (T, Test_Project_Polar'Access, "The projection onto the polar");
   end Register_Tests;

   overriding
   function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("Abacus.Qp.Cones");
   end Name;

end Abacus_Qp_Cones_Tests;
