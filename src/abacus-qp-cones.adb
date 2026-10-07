with Abacus.Arith; use Abacus.Arith;
with Abacus.Elementary;

package body Abacus.Qp.Cones
  with SPARK_Mode
is

   --  The largest square of a value.
   Square_Bound : constant := 2**(2 * Val_Bits);

   function Norm (V : Vector; From : Positive; To : Count) return Norm_Result
   is
      S : Wide := 0;
   begin
      for I in From .. To loop
         S := S + Wide (V (I)) * Wide (V (I));
         pragma Loop_Invariant (S in 0 .. Wide (I - From + 1) * Square_Bound);
      end loop;
      if S > Elementary.Root_Arg'Last then
         return (Fits => False, Value => 0);
      end if;
      return (Fits => True, Value => Elementary.Root (S));
   end Norm;

   --  R - S held to 0 .. Beyond, for a norm R and a head S.
   function Above (R : Nonnegative; S : Val) return Wide
   is (Wide'Max (0, Wide (R) - Wide (S)));

   function Excess (V : Vector; Head, Last : Index) return Wide is
      R : constant Norm_Result := Norm (V, Head + 1, Last);
   begin
      return (if R.Fits then Above (R.Value, V (Head)) else Beyond);
   end Excess;

   function Polar_Excess (V : Vector; Head, Last : Index) return Wide is
      R : constant Norm_Result := Norm (V, Head + 1, Last);
   begin
      return (if R.Fits then Above (R.Value, -V (Head)) else Beyond);
   end Polar_Excess;

   --  The run scaled onto the boundary, for a norm R above |S|: the head
   --  becomes (S + R) / 2 and each other entry U becomes U (S + R) / (2 R).
   procedure To_Boundary
     (V          : in out Vector;
      Head, Last : Index;
      R          : Nonnegative;
      Ok         : in out Boolean)
   with
     Pre => Is_Run (V, Head, Last) and then R > V (Head) and then R > -V (Head)
   is
      Sum : constant Wide := Wide (V (Head)) + Wide (R);
   begin
      for I in Head + 1 .. Last loop
         Store (Div_Round (Wide (V (I)) * Sum, 2 * Wide (R)), V (I), Ok);
      end loop;
      Store (Div_Round (Sum, 2), V (Head), Ok);
   end To_Boundary;

   procedure Project
     (V : in out Vector; Head, Last : Index; Ok : in out Boolean)
   is
      R : constant Norm_Result := Norm (V, Head + 1, Last);
   begin
      if not R.Fits then
         Ok := False;
      elsif R.Value <= V (Head) then
         null;
      elsif R.Value <= -V (Head) then
         V (Head .. Last) := [others => 0];
      else
         To_Boundary (V, Head, Last, R.Value, Ok);
      end if;
   end Project;

   procedure Negate (V : in out Vector; Head, Last : Index)
   with Pre => Is_Run (V, Head, Last)
   is
   begin
      for I in Head .. Last loop
         V (I) := -V (I);
      end loop;
   end Negate;

   procedure Project_Polar
     (V : in out Vector; Head, Last : Index; Ok : in out Boolean) is
   begin
      Negate (V, Head, Last);
      Project (V, Head, Last, Ok);
      Negate (V, Head, Last);
   end Project_Polar;

end Abacus.Qp.Cones;
