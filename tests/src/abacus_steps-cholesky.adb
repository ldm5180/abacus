with Abacus;          use Abacus;
with Abacus.Cholesky; use Abacus.Cholesky;
with Abacus.Matrices;
with Abacus.Text;

with Abacus_Steps.Flows;

package body Abacus_Steps.Cholesky is

   --  Empty until a matrix is given; Held; Settling while a factor's
   --  outcome settles; then Factored or Refused, and Solved once a system
   --  has been solved.
   type State is (Empty, Held, Settling, Factored, Refused, Solved);

   type Guard_Kind is
     (Always,
      Table_Read,
      Square_Read,
      Floor_Read,
      Gram_Ok,
      Factors,
      Rhs_Read,
      Fit_Read,
      Column_Read,
      Solution_Read);

   type Action_Kind is
     (A_Nothing,
      A_Hold,
      A_Factor,
      A_Factor_Gram,
      A_Solve,
      A_Fit,
      A_Check_Refused,
      A_Check_Solution,
      A_Refuse_Table,
      A_Refuse_Floor,
      A_Refuse_Rhs,
      A_Refuse_Fit,
      A_Refuse_Column,
      A_Refuse_Solution,
      A_Refuse_Factored,
      A_Refuse_Refused,
      A_Refuse_Unfactored);

   subtype Refuse_Action is
     Action_Kind range A_Refuse_Table .. A_Refuse_Unfactored;

   ---------------------------------------------------------------------
   --  The matrix a table states.
   ---------------------------------------------------------------------

   function Cell_Reads (Ctx : Step_Context; R, C : Positive) return Boolean
   is (Abacus.Text.Parse (Fabula.Args.Cell (Ctx.A, R, C)).Ok);

   function Table_Fits (Ctx : Step_Context) return Boolean
   is (Fabula.Args.Has_Table (Ctx.A)
       and then Fabula.Args.Row_Count (Ctx.A) in 1 .. Max_Side
       and then Fabula.Args.Col_Count (Ctx.A) in 1 .. Max_Side
       and then (for all R in 1 .. Fabula.Args.Row_Count (Ctx.A) =>
                   (for all C in 1 .. Fabula.Args.Col_Count (Ctx.A) =>
                      Cell_Reads (Ctx, R, C))));

   procedure Hold (Ctx : in out Step_Context) is
      F : Factoring renames Ctx.W.Chol;
   begin
      F :=
        (Rows   => Fabula.Args.Row_Count (Ctx.A),
         Cols   => Fabula.Args.Col_Count (Ctx.A),
         others => <>);
      for R in 1 .. F.Rows loop
         for C in 1 .. F.Cols loop
            F.M (R, C) :=
              Abacus.Text.Parse (Fabula.Args.Cell (Ctx.A, R, C)).Value;
         end loop;
      end loop;
   end Hold;

   function Held_Matrix (F : Factoring) return Matrix is
      Result : Matrix (1 .. F.Rows, 1 .. F.Cols);
   begin
      for R in Result'Range (1) loop
         for C in Result'Range (2) loop
            Result (R, C) := F.M (R, C);
         end loop;
      end loop;
      return Result;
   end Held_Matrix;

   ---------------------------------------------------------------------
   --  Factoring, solving and fitting.
   ---------------------------------------------------------------------

   function Floor_Of (Ctx : Step_Context; N : Positive) return Pivot
   is (Pivot'Max (1, Decimal_Of (Ctx, N)));

   --  The factor of A, and its outcome, into the world: on Factored the
   --  held matrix becomes L.
   procedure Record_Factor
     (Ctx : in out Step_Context; A : Matrix; N : Positive)
   is
      L       : Matrix := A;
      D       : Pivots (L'Range (1));
      Outcome : Factor_Outcome;
   begin
      Factor (L, D, Floor_Of (Ctx, N), Outcome);
      Ctx.W.Chol.Refused := Outcome.Result /= Abacus.Cholesky.Factored;
      Ctx.W.Chol.Column := Outcome.Column;
      for R in L'Range (1) loop
         for C in L'Range (2) loop
            Ctx.W.Chol.M (R, C) := L (R, C);
         end loop;
      end loop;
      Ctx.W.Chol.Rows := L'Length (1);
      Ctx.W.Chol.Cols := L'Length (2);
   end Record_Factor;

   --  The Gram matrix of the held data, and whether it fits the values.
   procedure Gram_Of (F : Factoring; G : out Matrix; Ok : out Boolean) is
   begin
      Matrices.Gram (Held_Matrix (F), G, Ok);
   end Gram_Of;

   function Gram_Fits (F : Factoring) return Boolean is
      G  : Matrix (1 .. F.Cols, 1 .. F.Cols);
      Ok : Boolean;
   begin
      Gram_Of (F, G, Ok);
      return Ok;
   end Gram_Fits;

   procedure Factor_Gram (Ctx : in out Step_Context) is
      G  : Matrix (1 .. Ctx.W.Chol.Cols, 1 .. Ctx.W.Chol.Cols);
      Ok : Boolean;
   begin
      Gram_Of (Ctx.W.Chol, G, Ok);
      Record_Factor (Ctx, G, 1);
   end Factor_Gram;

   --  The pivots are L's diagonal, as Factor leaves it.
   function Pivots_Of (F : Factoring) return Pivots is
      D : Pivots (1 .. F.Rows);
   begin
      for I in D'Range loop
         D (I) := Pivot'Max (1, F.M (I, I));
      end loop;
      return D;
   end Pivots_Of;

   procedure Solve (Ctx : in out Step_Context) is
      F      : Factoring renames Ctx.W.Chol;
      B      : Vector :=
        Parse_List (Fabula.Args.Text (Ctx.A, 1)).Values (1 .. F.Rows);
      Result : Solve_Result;
   begin
      Abacus.Cholesky.Solve (Held_Matrix (F), Pivots_Of (F), B, Result);
      F.Solution (B'Range) := B;
   end Solve;

   procedure Fit (Ctx : in out Step_Context) is
      F       : Factoring renames Ctx.W.Chol;
      Y       : constant Vector :=
        Parse_List (Fabula.Args.Text (Ctx.A, 1)).Values (1 .. F.Rows);
      Beta    : Vector (1 .. F.Cols);
      Outcome : Factor_Outcome;
   begin
      Least_Squares (Held_Matrix (F), Y, Decimal_Of (Ctx, 2), Beta, Outcome);
      F.Refused := Outcome.Result /= Abacus.Cholesky.Factored;
      F.Column := Outcome.Column;
      F.Solution (Beta'Range) := Beta;
   end Fit;

   function Count_Of (Ctx : Step_Context; N : Positive) return Natural
   is (Parse_List (Fabula.Args.Text (Ctx.A, N)).Count);

   function Solution_Near (Ctx : Step_Context) return Boolean is
      Want : constant Number_List := Parse_List (Fabula.Args.Text (Ctx.A, 2));
   begin
      return
        (for all I in 1 .. Want.Count =>
           abs (Ctx.W.Chol.Solution (I) - Want.Values (I))
           <= Decimal_Of (Ctx, 1));
   end Solution_Near;

   function Solution_Text (F : Factoring; Count : Natural) return String
   is (if Count = 0
       then ""
       else
         Solution_Text (F, Count - 1)
         & (if Count > 1 then ", " else "")
         & Abacus.Text.Image (F.Solution (Count)));

   ---------------------------------------------------------------------
   --  The machine.
   ---------------------------------------------------------------------

   function Evaluate
     (G : Guard_Kind; Ctx : Step_Context; Evt : Step_Kind) return Boolean
   is
      pragma Unreferenced (Evt);
      F : Factoring renames Ctx.W.Chol;
   begin
      return
        (case G is
           when Always        => True,
           when Table_Read    => Table_Fits (Ctx),
           when Square_Read   =>
             Table_Fits (Ctx)
             and then Fabula.Args.Row_Count (Ctx.A)
                      = Fabula.Args.Col_Count (Ctx.A),
           when Floor_Read    =>
             Decimal_Read (Ctx) and then Decimal_Of (Ctx) > 0,
           when Gram_Ok       =>
             Decimal_Read (Ctx)
             and then Decimal_Of (Ctx) > 0
             and then Gram_Fits (F),
           when Factors       => not F.Refused,
           when Rhs_Read      =>
             Parse_List (Fabula.Args.Text (Ctx.A, 1)).Ok
             and then Count_Of (Ctx, 1) = F.Rows,
           when Fit_Read      =>
             Parse_List (Fabula.Args.Text (Ctx.A, 1)).Ok
             and then Count_Of (Ctx, 1) = F.Rows
             and then Decimal_Read (Ctx, 2),
           when Column_Read   => Units_Read (Ctx),
           when Solution_Read =>
             Decimal_Read (Ctx, 1)
             and then Parse_List (Fabula.Args.Text (Ctx.A, 2)).Ok);
   end Evaluate;

   function Refusal (A : Refuse_Action; Ctx : Step_Context) return String
   is (case A is
         when A_Refuse_Table      =>
           "a matrix is a table of decimal numbers, at most"
           & Max_Side'Image
           & " each way, and square to be factored",
         when A_Refuse_Floor      => "a floor is a positive decimal number",
         when A_Refuse_Rhs        =>
           "a right side has one number per row of the matrix",
         when A_Refuse_Fit        =>
           "a fitted column has one number per row, and a ridge",
         when A_Refuse_Column     => "a column is a whole number",
         when A_Refuse_Solution   => "a solution is checked against numbers",
         when A_Refuse_Factored   => "the matrix factored",
         when A_Refuse_Refused    =>
           "the factorization was refused at column" & Ctx.W.Chol.Column'Image,
         when A_Refuse_Unfactored => "nothing has been factored or solved");

   procedure Check_Refused (Ctx : in out Step_Context) is
   begin
      Fabula.Check.Is_True
        (Ctx.R,
         Raw (Ctx.W.Chol.Column) = Units_Of (Ctx),
         "the factorization was refused at column" & Ctx.W.Chol.Column'Image);
   end Check_Refused;

   procedure Execute
     (A : Action_Kind; Ctx : in out Step_Context; Evt : Step_Kind)
   is
      pragma Unreferenced (Evt);
   begin
      case A is
         when A_Nothing        =>
            null;

         when A_Hold           =>
            Hold (Ctx);

         when A_Factor         =>
            Record_Factor (Ctx, Held_Matrix (Ctx.W.Chol), 1);
            Then_Take (Ctx, E_Factor_Settled);

         when A_Factor_Gram    =>
            Factor_Gram (Ctx);
            Then_Take (Ctx, E_Factor_Settled);

         when A_Solve          =>
            Solve (Ctx);

         when A_Fit            =>
            Fit (Ctx);
            Then_Take (Ctx, E_Factor_Settled);

         when A_Check_Refused  =>
            Check_Refused (Ctx);

         when A_Check_Solution =>
            Fabula.Check.Is_True
              (Ctx.R,
               Solution_Near (Ctx),
               "the solution is "
               & Solution_Text (Ctx.W.Chol, Count_Of (Ctx, 2)));

         when Refuse_Action    =>
            Fabula.Check.Fail_Step (Ctx.R, Refusal (A, Ctx));
      end case;
   end Execute;

   package Flow is new
     Abacus_Steps.Flows
       (State       => State,
        Guard_Kind  => Guard_Kind,
        Action_Kind => Action_Kind,
        Evaluate    => Evaluate,
        Execute     => Execute,
        Always      => Always,
        Nothing     => A_Nothing);

   use Flow.Machines;
   use Flow.Op;

   Give_Data_Matrix : constant Ev := (Kind => E_Give_Data_Matrix);
   Give_Symmetric   : constant Ev := (Kind => E_Give_Symmetric);
   Factor_Gram_Ev   : constant Ev := (Kind => E_Factor_Gram);
   Factor_Ev        : constant Ev := (Kind => E_Factor);
   Solve_Ev         : constant Ev := (Kind => E_Solve);
   Fit_Ev           : constant Ev := (Kind => E_Fit);
   Check_Factors    : constant Ev := (Kind => E_Check_Factors);
   Check_Refused_At : constant Ev := (Kind => E_Check_Refused_At);
   Check_Solution   : constant Ev := (Kind => E_Check_Solution);

   --  An event no step names: a factor's outcome settles which state the
   --  factoring reached.
   Factor_Settled : constant Ev := (Kind => E_Factor_Settled);

   --!format off
   Table : constant Transition_Table :=
     [Empty    + Give_Data_Matrix (Table_Read)    / A_Hold              >= Held,
      Empty    + Give_Data_Matrix                 / A_Refuse_Table      >= Empty,
      Empty    + Give_Symmetric   (Square_Read)   / A_Hold              >= Held,
      Empty    + Give_Symmetric                   / A_Refuse_Table      >= Empty,
      Empty    + Check_Factors                    / A_Refuse_Unfactored >= Empty,
      Empty    + Check_Refused_At                 / A_Refuse_Unfactored >= Empty,
      Empty    + Check_Solution                   / A_Refuse_Unfactored >= Empty,
      Held     + Factor_Gram_Ev   (Gram_Ok)       / A_Factor_Gram       >= Settling,
      Held     + Factor_Gram_Ev                   / A_Refuse_Floor      >= Held,
      Held     + Factor_Ev        (Floor_Read)    / A_Factor            >= Settling,
      Held     + Factor_Ev                        / A_Refuse_Floor      >= Held,
      Held     + Fit_Ev           (Fit_Read)      / A_Fit               >= Settling,
      Held     + Fit_Ev                           / A_Refuse_Fit        >= Held,
      Settling + Factor_Settled   (Factors)                             >= Factored,
      Settling + Factor_Settled                                         >= Refused,
      Factored + Check_Factors                                          >= Factored,
      Factored + Check_Refused_At                 / A_Refuse_Factored   >= Factored,
      Factored + Solve_Ev         (Rhs_Read)      / A_Solve             >= Solved,
      Factored + Solve_Ev                         / A_Refuse_Rhs        >= Factored,
      Factored + Check_Solution   (Solution_Read) / A_Check_Solution    >= Factored,
      Factored + Check_Solution                   / A_Refuse_Solution   >= Factored,
      Refused  + Check_Refused_At (Column_Read)   / A_Check_Refused     >= Refused,
      Refused  + Check_Refused_At                 / A_Refuse_Column     >= Refused,
      Refused  + Check_Factors                    / A_Refuse_Refused    >= Refused,
      Refused  + Solve_Ev                         / A_Refuse_Refused    >= Refused,
      Refused  + Check_Solution                   / A_Refuse_Refused    >= Refused,
      Solved   + Check_Solution   (Solution_Read) / A_Check_Solution    >= Solved,
      Solved   + Check_Solution                   / A_Refuse_Solution   >= Solved];
   --!format on

   Current : State := Empty;

   procedure Offer
     (Ctx : in out Step_Context; Evt : Step_Kind; Handled : out Boolean) is
   begin
      Flow.Take (Table, Current, Ctx, Evt, Handled);
   end Offer;

   procedure Reset is
   begin
      Current := Empty;
   end Reset;

   function Phase return String
   is (Current'Image);

end Abacus_Steps.Cholesky;
