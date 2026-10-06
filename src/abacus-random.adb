package body Abacus.Random
  with SPARK_Mode
is

   use Interfaces;

   Golden : constant := 16#9E37_79B9_7F4A_7C15#;
   Mix_1  : constant := 16#BF58_476D_1CE4_E5B9#;
   Mix_2  : constant := 16#94D0_49BB_1331_11EB#;

   procedure Next (G : in out Generator; X : out Unsigned_64) is
      Z : Unsigned_64;
   begin
      G.State := G.State + Golden;
      Z := G.State;
      Z := (Z xor Shift_Right (Z, 30)) * Mix_1;
      Z := (Z xor Shift_Right (Z, 27)) * Mix_2;
      X := Z xor Shift_Right (Z, 31);
   end Next;

   procedure Below (G : in out Generator; N : Unsigned_64; X : out Unsigned_64)
   is
      --  2**64 mod N: the draws below it are the part of the range a
      --  whole multiple of N does not cover.
      Threshold : constant Unsigned_64 := (0 - N) mod N;
      R         : Unsigned_64;
   begin
      Next (G, R);
      for Redraw in 1 .. Max_Redraws loop
         exit when R >= Threshold;
         Next (G, R);
      end loop;
      X := R mod N;
   end Below;

end Abacus.Random;
