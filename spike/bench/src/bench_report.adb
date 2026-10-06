with Ada.Command_Line;
with Ada.Text_IO; use Ada.Text_IO;

package body Bench_Report is

   Milli_Per_Second : constant := 1_000;
   Nano_Per_Second  : constant := 1_000_000_000;

   function Profile return String
   is (if Ada.Command_Line.Argument_Count >= 1
       then Ada.Command_Line.Argument (1)
       else "unknown");

   procedure Report
     (What : String; Frac, Size : Natural; Span : Ada.Real_Time.Time_Span) is
   begin
      Put_Line
        (Profile
         & ","
         & What
         & ","
         & Frac'Image
         & ","
         & Size'Image
         & ","
         & Duration'Image
             (Ada.Real_Time.To_Duration (Span) * Milli_Per_Second));
   end Report;

   procedure Report_Per
     (What       : String;
      Frac, Size : Natural;
      Span       : Ada.Real_Time.Time_Span;
      Ops        : Positive)
   is
      Seconds : constant Duration := Ada.Real_Time.To_Duration (Span);
   begin
      Put_Line
        (Profile
         & ","
         & What
         & ","
         & Frac'Image
         & ","
         & Size'Image
         & ","
         & Duration'Image (Seconds * Nano_Per_Second / Ops));
   end Report_Per;

end Bench_Report;
