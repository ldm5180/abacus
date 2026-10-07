with Abacus.Sobol.Directions;

package body Abacus.Sobol
  with SPARK_Mode
is

   use Interfaces;

   --  Dimension 1's direction numbers: number K is 2**(32 - K).
   function First_Directions return Direction_Numbers
   is ([for K in Digit => Shift_Left (1, Bits - K)]);

   --  Dimension J's direction numbers from its polynomial's degree S,
   --  inner coefficients A and initial numbers M, by the recurrence
   --  V (K) = V (K - S) xor V (K - S) / 2**S xor the a_i V (K - i).
   function Listed_Directions (J : Directions.Listed) return Direction_Numbers
   is
      use Abacus.Sobol.Directions;
      S : constant Degree_Value := Degree (J);
      A : constant Natural := Coded (J);
      V : Direction_Numbers := [others => 0];
   begin
      for K in 1 .. S loop
         V (K) := Shift_Left (Unsigned_32 (Initial (J, K)), Bits - K);
      end loop;
      for K in S + 1 .. Digit'Last loop
         V (K) := V (K - S) xor Shift_Right (V (K - S), S);
         for I in 1 .. S - 1 loop
            if (A / 2**(S - 1 - I)) mod 2 = 1 then
               V (K) := V (K) xor V (K - I);
            end if;
         end loop;
      end loop;
      return V;
   end Listed_Directions;

   function Directions_Of (J : Dimension) return Direction_Numbers
   is (if J = 1 then First_Directions else Listed_Directions (J));

   function Unscrambled (D : Dimension) return Sequence
   is ((D       => D,
        V       => [for J in 1 .. D => Directions_Of (J)],
        Current => [others => 0],
        Count   => 0));

   --  The digit the point after the one at index N differs in: one more
   --  than how many low bits of N are one.
   function Changed_Digit (N : Point_Count) return Digit
   with Pre => N < Period - 1
   is
      C : Digit := 1;
   begin
      while C < Bits and then (N / 2**(C - 1)) mod 2 = 1 loop
         pragma Loop_Invariant (C in 1 .. Bits - 1);
         pragma Loop_Variant (Increases => C);
         C := C + 1;
      end loop;
      return C;
   end Changed_Digit;

   procedure Next (S : in out Sequence; X : out Point; Ok : out Boolean) is
   begin
      X := [others => 0];
      Ok := S.Count < Period;
      if not Ok then
         return;
      end if;
      X := S.Current;
      if S.Count < Period - 1 then
         for J in 1 .. S.D loop
            S.Current (J) :=
              S.Current (J) xor S.V (J) (Changed_Digit (S.Count));
         end loop;
      end if;
      S.Count := S.Count + 1;
   end Next;

end Abacus.Sobol;
