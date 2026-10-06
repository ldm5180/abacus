package body Abacus.Arith
  with SPARK_Mode
is

   procedure Store (W : Wide; V : in out Val; Ok : in out Boolean) is
   begin
      if Fits (W) then
         V := Val (W);
      else
         Ok := False;
      end if;
   end Store;

end Abacus.Arith;
