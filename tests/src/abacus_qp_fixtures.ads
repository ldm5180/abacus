with Abacus;    use Abacus;
with Abacus.Qp; use Abacus.Qp;

--  The quadratic programs tools/make_qp.py wrote under tests/data, and
--  their oracle answers.  Not SPARK: it reads files.

package Abacus_Qp_Fixtures is

   --  The problem in tests/data/qp_<Name>.txt.
   function Load (Name : String) return Problem;

   --  Whether that file holds an oracle answer, and the answer.
   function Has_Answer (Name : String) return Boolean;

   function Answer (Name : String) return Vector;

end Abacus_Qp_Fixtures;
