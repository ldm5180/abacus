with Ada.Containers.Vectors;

with Abacus; use Abacus;

--  The oracle fixtures under tests/data, written by the tools/ scripts:
--  lines of a word and raw integers at Frac 40.  Not SPARK: it reads
--  files.  Paths are relative to the crate root, where the suite runs.

package Abacus_Fixtures is

   Max_Fields : constant := 8;

   type Fields is array (1 .. Max_Fields) of Raw;

   --  One line: its first word, and the integers after it.
   type Line is record
      Tag    : String (1 .. 8) := [others => ' '];
      Count  : Natural := 0;
      Values : Fields := [others => 0];
   end record;

   package Line_Vectors is new Ada.Containers.Vectors (Positive, Line);

   --  Every line of tests/data/Name after its header line.
   function Lines (Name : String) return Line_Vectors.Vector;

   --  Whether a line's first word is Tag.
   function Is_Tagged (L : Line; Tag : String) return Boolean;

end Abacus_Fixtures;
