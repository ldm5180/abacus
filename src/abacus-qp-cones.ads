--  The second-order cone {(s, u) : ||u|| <= s}, over a run V (Head ..
--  Last) of a vector: s is V (Head), u the rest.  Its norm is the proved
--  integer root of a sum of squares formed exactly at 128 bits; the
--  projection onto it is closed form.  The cone is its own dual, and its
--  polar is its negative, {(s, u) : ||u|| <= -s}.

package Abacus.Qp.Cones
  with SPARK_Mode
is

   --  Whether V (Head .. Last) is a run of V.
   function Is_Run (V : Vector; Head, Last : Index) return Boolean
   is (Head <= Last and then Head >= V'First and then Last <= V'Last);

   --  The norm of V (From .. To), rounded to nearest, when it is a
   --  value; zero for an empty span.
   type Norm_Result is record
      Fits  : Boolean := True;
      Value : Nonnegative := 0;
   end record;

   function Norm (V : Vector; From : Positive; To : Count) return Norm_Result
   with Pre => (if From <= To then From >= V'First and then To <= V'Last);

   --  An excess past every tolerance: what a norm that is not a value
   --  counts as.
   Beyond : constant := 4 * Val_Bound;

   --  How far the run lies outside the cone, at most: ||u|| - s, or zero
   --  inside.  It bounds the distance to the cone from above.
   function Excess (V : Vector; Head, Last : Index) return Wide
   with Pre => Is_Run (V, Head, Last), Post => Excess'Result in 0 .. Beyond;

   --  How far the run lies outside the polar cone, at most: ||u|| + s.
   function Polar_Excess (V : Vector; Head, Last : Index) return Wide
   with
     Pre  => Is_Run (V, Head, Last),
     Post => Polar_Excess'Result in 0 .. Beyond;

   --  The run projected onto the cone: kept inside it, zero inside its
   --  polar, otherwise ((s + r) / 2, u (s + r) / (2 r)), r = ||u||.  Ok
   --  is cleared when the norm is not a value, and the run left as it
   --  was.
   procedure Project
     (V : in out Vector; Head, Last : Index; Ok : in out Boolean)
   with Pre => Is_Run (V, Head, Last);

   --  The run projected onto the polar cone: the negative of the
   --  negated run's projection onto the cone.
   procedure Project_Polar
     (V : in out Vector; Head, Last : Index; Ok : in out Boolean)
   with Pre => Is_Run (V, Head, Last);

   ---------------------------------------------------------------------
   --  A problem's cones, as runs of its general rows.
   ---------------------------------------------------------------------

   --  Whether general row R lies in a cone.
   function In_Cone (Pr : Problem; R : Index) return Boolean
   is (R <= Pr.K and then Pr.Kind (R) /= Interval);

   --  Whether general row R begins a cone: a head, or a tail with no cone
   --  above it.
   function Starts_Cone (Pr : Problem; R : Index) return Boolean
   is (In_Cone (Pr, R)
       and then (Pr.Kind (R) = Cone_Head
                 or else R = 1
                 or else Pr.Kind (R - 1) = Interval));

   --  The last row of the cone that begins at Head: the last of the tail
   --  rows right after it.
   function Cone_Last (Pr : Problem; Head : Index) return Index
   with
     Pre  => Starts_Cone (Pr, Head),
     Post => Cone_Last'Result in Head .. Pr.K;

   --  Whether any general row lies in a cone.
   function Has_Cone (Pr : Problem) return Boolean
   is (for some R in 1 .. Pr.K => Pr.Kind (R) /= Interval);

end Abacus.Qp.Cones;
