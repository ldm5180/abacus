with AUnit.Assertions; use AUnit.Assertions;

with Abacus;            use Abacus;
with Abacus.Qp;         use Abacus.Qp;
with Abacus.Qp.Scaling; use Abacus.Qp.Scaling;

package body Abacus_Qp_Scaling_Tests is

   --  A value's exponent: the power of two at or below its magnitude.
   procedure Test_Exponent (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Assert (Exponent_Of (One) = 0, "one");
      Assert (Exponent_Of (1) = -Frac, "a unit");
      Assert (Exponent_Of (3 * One) = 1, "three");
      Assert (Exponent_Of (-One / 2) = -1, "minus a half");
      Assert (Exponent_Of (Val'Last) = Val_Bits - Frac, "the last");
      Assert (Exponent_Of (Val'Last - 1) = Val_Bits - Frac - 1, "below it");
   end Test_Exponent;

   --  One variable, P = 1, held at least zero by its box, and a row of
   --  16 equal to one.  Equilibration scales the variable by 2**-2, the
   --  row by 2**-2 and the box by 2**1, which leaves every entry of the
   --  scaled problem within a factor of two of one, and the cost by
   --  2**4, which brings P back to one.  The equivalent steps: the
   --  row's 2**(2 * -2 - 4) of the setting's, the box's 2**(2 - 4), the
   --  proximal term's 2**(4 - 4).
   procedure Test_One_Row (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Pr   : constant Problem :=
        (N      => 1,
         K      => 1,
         P      => [[One]],
         Q      => [0],
         Lo     => [0],
         Hi     => [No_Upper],
         E      => [[16 * One]],
         Row_Lo => [One],
         Row_Hi => [One],
         Kind   => [Interval]);
      S    : constant Settings :=
        (Default_Settings with delta Equilibrate => 10);
      Work : Workspace (1, 1);
   begin
      Set_Steps (Pr, S, Work);
      Assert (Work.Row_Step (1) = S.Row_Shift - 8, "the row");
      Assert (Work.Box_Step (1) = S.Rho_Shift - 2, "the box");
      Assert (Work.Prox_Step (1) = S.Sigma_Shift, "the proximal term");
      Set_Steps (Pr, (S with delta Equilibrate => 0), Work);
      Assert
        (Work.Row_Step (1) = S.Row_Shift
         and then Work.Box_Step (1) = S.Rho_Shift
         and then Work.Prox_Step (1) = S.Sigma_Shift,
         "no equilibration: the settings' own");
   end Test_One_Row;

   --  A cone's rows are scaled together, so its projection stays the
   --  cone's: a tail row of sixteen beside one of one takes the same
   --  step, where two interval rows so posed would not.
   procedure Test_Cone_Shares (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      S    : constant Settings :=
        (Default_Settings with delta Equilibrate => 10);
      Pr   : Problem :=
        (N      => 2,
         K      => 3,
         P      => [[0, 0], [0, 0]],
         Q      => [-One, -One],
         Lo     => [No_Lower, No_Lower],
         Hi     => [No_Upper, No_Upper],
         E      => [[0, 0], [One, 0], [0, 16 * One]],
         Row_Lo => [-One, 0, 0],
         Row_Hi => [No_Upper, No_Upper, No_Upper],
         Kind   => [Cone_Head, Cone_Tail, Cone_Tail]);
      Work : Workspace (2, 3);
   begin
      Set_Steps (Pr, S, Work);
      Assert
        (Work.Row_Step (1) = Work.Row_Step (2)
         and then Work.Row_Step (2) = Work.Row_Step (3),
         "one step for the cone");
      Pr.Kind := [others => Interval];
      Set_Steps (Pr, S, Work);
      Assert
        (Work.Row_Step (2) /= Work.Row_Step (3), "two intervals, two steps");
   end Test_Cone_Shares;

   overriding
   procedure Register_Tests (T : in out Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine (T, Test_Exponent'Access, "A value's exponent");
      Register_Routine (T, Test_One_Row'Access, "A row of sixteen");
      Register_Routine (T, Test_Cone_Shares'Access, "A cone's rows share");
   end Register_Tests;

   overriding
   function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("Abacus.Qp.Scaling");
   end Name;

end Abacus_Qp_Scaling_Tests;
