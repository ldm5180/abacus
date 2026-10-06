with AUnit.Assertions; use AUnit.Assertions;

with Abacus;            use Abacus;
with Abacus.Arith;      use Abacus.Arith;
with Abacus.Elementary; use Abacus.Elementary;
with Abacus_Fixtures;   use Abacus_Fixtures;

package body Abacus_Elementary_Tests is

   --  The approximations' stated errors, in units: 7.5e-8 for the CDF,
   --  and the bound the inverse keeps against scipy's binary64 ndtri.
   Cdf_Error     : constant := 82_464;
   Inverse_Error : constant := 2;

   --  How far each function may sit from its own definition, evaluated
   --  in 60 decimal digits and rounded to the grid.
   Exp_Slack     : constant := 1;
   Log_Slack     : constant := 1;
   Cdf_Slack     : constant := 2;
   Inverse_Slack : constant := 2;

   --  Just under exp 11.75, which is 126,753.36.
   Exp_At_Ceiling : constant := 126_753 * One;

   --  Exp's slack scales with its result above one: a unit of the
   --  mantissa is 2**E units of the result.
   function Exp_Within (Got, Want : Raw) return Boolean
   is (abs (Got - Want) <= Exp_Slack + Want / 2**Frac);

   function Rows (Tag : String) return Line_Vectors.Vector is
      All_Lines : constant Line_Vectors.Vector := Lines ("elementary.txt");
      Result    : Line_Vectors.Vector;
   begin
      for L of All_Lines loop
         if Is_Tagged (L, Tag) then
            Result.Append (L);
         end if;
      end loop;
      return Result;
   end Rows;

   function Report (L : Line; Got : Raw) return String
   is (L.Tag
       & L.Values (1)'Image
       & " gives"
       & Got'Image
       & ", want"
       & L.Values (2)'Image);

   --  The root is the nearest integer: (R - 1/2)**2 <= X <= (R + 1/2)**2.
   procedure Nearest (X : Root_Arg) is
      R : constant Wide := Wide (Root (X));
   begin
      Assert
        (4 * R * R - 4 * R + 1 <= 4 * X
         and then 4 * X <= 4 * R * R + 4 * R + 1,
         "root of" & X'Image & " is" & R'Image);
   end Nearest;

   procedure Test_Root (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Assert (Root (0) = 0 and then Root (1) = 1, "zero and one");
      Assert (Root (2) = 1 and then Root (3) = 2, "two and three");
      Nearest (Root_Arg'Last);
      for K in 0 .. Root_Bits - 1 loop
         Nearest (2**K);
         Nearest (2**K + 2**(K / 2));
      end loop;
   end Test_Root;

   procedure Test_Sqrt (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      for L of Rows ("sqrt") loop
         Assert
           (Sqrt (L.Values (1)) = L.Values (2),
            Report (L, Sqrt (L.Values (1))));
      end loop;
      Assert
        (Mul (Sqrt (2 * One), Sqrt (2 * One)) - 2 * One in -2 .. 2,
         "the root of two, squared");
   end Test_Sqrt;

   procedure Test_Exp (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      for L of Rows ("exp") loop
         Assert
           (Exp_Within (Exp (L.Values (1)), L.Values (2)),
            Report (L, Exp (L.Values (1))));
      end loop;
      Assert (Exp (0) = One, "exp 0");
      Assert (Exp (Exp_Floor - 1) = 0, "below the floor");
      Assert (Exp (Val'First) = 0, "far below");
      Assert (Exp (Exp_Ceiling) > Exp_At_Ceiling, "the ceiling");
   end Test_Exp;

   procedure Test_Log (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      for L of Rows ("log") loop
         Assert
           (abs (Log (L.Values (1)) - L.Values (2)) <= Log_Slack,
            Report (L, Log (L.Values (1))));
      end loop;
      Assert (Log (One) = 0, "log 1");
      Assert (abs (Log (Exp (One)) - One) <= 2, "log e");
      Assert (abs (Exp (Log (3 * One)) - 3 * One) <= 4, "exp log 3");
   end Test_Log;

   procedure Test_Cdf (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Got : Raw;
   begin
      for L of Rows ("cdf") loop
         Got := Norm_Cdf (L.Values (1));
         Assert (abs (Got - L.Values (2)) <= Cdf_Slack, Report (L, Got));
         Assert
           (abs (Got - L.Values (3)) <= Cdf_Error,
            Report (L, Got) & " (true)");
      end loop;
      Assert (abs (Norm_Cdf (0) - One / 2) <= Cdf_Error, "the middle");
      Assert
        (Norm_Cdf (Val'Last) = One and then Norm_Cdf (Val'First) = 0,
         "the ends");
   end Test_Cdf;

   procedure Test_Inverse (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Got : Raw;
   begin
      for L of Rows ("inv") loop
         Got := Inv_Norm_Cdf (L.Values (1));
         Assert (abs (Got - L.Values (2)) <= Inverse_Slack, Report (L, Got));
         Assert
           (abs (Got - L.Values (3)) <= Inverse_Error,
            Report (L, Got) & " (true)");
         Assert
           (abs (Norm_Cdf (Got) - L.Values (1)) <= Cdf_Error, "the CDF of it");
      end loop;
      Assert (Inv_Norm_Cdf (One / 2) = 0, "the median");
   end Test_Inverse;

   overriding
   procedure Register_Tests (T : in out Test) is
      use AUnit.Test_Cases.Registration;
   begin
      Register_Routine (T, Test_Root'Access, "The integer root is nearest");
      Register_Routine (T, Test_Sqrt'Access, "Sqrt against the fixture");
      Register_Routine (T, Test_Exp'Access, "Exp against the fixture");
      Register_Routine (T, Test_Log'Access, "Log against the fixture");
      Register_Routine (T, Test_Cdf'Access, "The CDF, both ways");
      Register_Routine (T, Test_Inverse'Access, "The inverse CDF, both ways");
   end Register_Tests;

   overriding
   function Name (T : Test) return AUnit.Message_String is
      pragma Unreferenced (T);
   begin
      return AUnit.Format ("Abacus.Elementary");
   end Name;

end Abacus_Elementary_Tests;
