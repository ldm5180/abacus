with Ada.Characters.Handling;
with Ada.Strings.Fixed;

with Abacus;         use Abacus;
with Abacus.Sorting; use Abacus.Sorting;
with Abacus.Stats;   use Abacus.Stats;
with Abacus.Stats.Rolling;
with Abacus.Text;

with Abacus_Steps.Flows;

package body Abacus_Steps.Stats is

   use type Abacus.Stats.Rolling.Window;

   --  Empty until data are given; Holding them; Answered once a
   --  statistic has been taken of them.  Windowed once a window is
   --  opened, and Slid once a row has gone into or out of it.
   type State is (Empty, Holding, Answered, Windowed, Slid);

   type Guard_Kind is
     (Always,
      Data_Read,
      Quantile_Named,
      Answer_Read,
      Near_Read,
      Computable,
      Series_Read,
      Rows_Read,
      Row_Read,
      Removable,
      Pair_Read);

   type Action_Kind is
     (A_Nothing,
      A_Give,
      A_Give_Weights,
      A_Give_Second,
      A_Quantile,
      A_Compute,
      A_Open,
      A_Give_Rows,
      A_Add,
      A_Remove,
      A_Check_Answer,
      A_Check_Near,
      A_Check_Fresh,
      A_Check_Covariance,
      A_Refuse_Data,
      A_Refuse_Quantile,
      A_Refuse_Answer,
      A_Refuse_Compute,
      A_Refuse_Empty,
      A_Refuse_Window,
      A_Refuse_Row,
      A_Refuse_Remove,
      A_Refuse_Pair);

   subtype Give_Action is Action_Kind range A_Give .. A_Remove;
   subtype Check_Action is
     Action_Kind range A_Check_Answer .. A_Check_Covariance;
   subtype Refuse_Action is Action_Kind range A_Refuse_Data .. A_Refuse_Pair;

   function Lower (S : String) return String
   renames Ada.Characters.Handling.To_Lower;

   function Trim (S : String) return String
   is (Ada.Strings.Fixed.Trim (S, Ada.Strings.Both));

   function List_Of (Ctx : Step_Context) return Number_List
   is (Parse_List (Fabula.Args.Text (Ctx.A, 1)));

   function Held (Ctx : Step_Context) return Vector
   is (Ctx.W.Stats.Data (1 .. Ctx.W.Stats.Count));

   ---------------------------------------------------------------------
   --  Statistics by name.
   ---------------------------------------------------------------------

   type Statistic is
     (Mean,
      Weighted_Mean,
      Population_Variance,
      Sample_Variance,
      Population_Standard_Deviation,
      Sample_Standard_Deviation,
      Population_Covariance,
      Sample_Covariance,
      Correlation);

   --  A statistic as a sentence names it: "weighted mean".
   function Spoken (S : Statistic) return String is
      Name : String := Lower (S'Image);
   begin
      for C of Name loop
         if C = '_' then
            C := ' ';
         end if;
      end loop;
      return Name;
   end Spoken;

   function Said (Ctx : Step_Context) return String
   is (Lower (Trim (Fabula.Args.Text (Ctx.A, 1))));

   function Is_Statistic (Ctx : Step_Context) return Boolean
   is (for some S in Statistic => Spoken (S) = Said (Ctx));

   function Named (Ctx : Step_Context) return Statistic is
   begin
      for S in Statistic loop
         if Spoken (S) = Said (Ctx) then
            return S;
         end if;
      end loop;
      return Mean;
   end Named;

   --  Whether the table holds what the named statistic reads.
   function Ready (Ctx : Step_Context) return Boolean
   is (case Named (Ctx) is
         when Weighted_Mean                               =>
           Ctx.W.Stats.Weighed = Ctx.W.Stats.Count,
         when Population_Covariance .. Correlation        =>
           Ctx.W.Stats.Paired = Ctx.W.Stats.Count
           and then Ctx.W.Stats.Count >= 2,
         when Sample_Variance | Sample_Standard_Deviation =>
           Ctx.W.Stats.Count >= 2,
         when others                                      => True);

   function Second (Ctx : Step_Context) return Vector
   is (Ctx.W.Stats.Second (1 .. Ctx.W.Stats.Count));

   function Weights (Ctx : Step_Context) return Vector
   is (Ctx.W.Stats.Weights (1 .. Ctx.W.Stats.Count));

   function Compute (Ctx : Step_Context) return Val
   is (case Named (Ctx) is
         when Mean                          => Abacus.Stats.Mean (Held (Ctx)),
         when Weighted_Mean                 =>
           Abacus.Stats.Weighted_Mean (Held (Ctx), Weights (Ctx)),
         when Population_Variance           =>
           Variance (Held (Ctx), Population),
         when Sample_Variance               => Variance (Held (Ctx), Sample),
         when Population_Standard_Deviation =>
           Std_Dev (Held (Ctx), Population),
         when Sample_Standard_Deviation     => Std_Dev (Held (Ctx), Sample),
         when Population_Covariance         =>
           Covariance (Held (Ctx), Second (Ctx), Population),
         when Sample_Covariance             =>
           Covariance (Held (Ctx), Second (Ctx), Sample),
         when Correlation                   =>
           Abacus.Stats.Correlation (Held (Ctx), Second (Ctx)).Value);

   ---------------------------------------------------------------------
   --  The window, replayed from its log.
   ---------------------------------------------------------------------

   function Log (Ctx : Step_Context) return Window_Log
   is (Ctx.W.Stats.Window);

   function Row_Of (L : Window_Log; R : Row_Count) return Vector
   is (L.Rows (R) (1 .. L.Series));

   --  The window built as a caller builds one: every row given, in
   --  order, then the oldest removed one by one.
   function Slid (L : Window_Log) return Rolling.Window is
      W  : Rolling.Window := Rolling.Empty (L.Series);
      Ok : Boolean;
   begin
      for R in 1 .. L.Given loop
         Rolling.Add_Row (W, Row_Of (L, R));
      end loop;
      for R in 1 .. L.Removed loop
         Rolling.Remove_Row (W, Row_Of (L, R), Ok);
      end loop;
      return W;
   end Slid;

   --  A window built fresh over the rows that remain.
   function Fresh (L : Window_Log) return Rolling.Window is
      W : Rolling.Window := Rolling.Empty (L.Series);
   begin
      for R in L.Removed + 1 .. L.Given loop
         Rolling.Add_Row (W, Row_Of (L, R));
      end loop;
      return W;
   end Fresh;

   --  Rows in a step are separated by this.
   Row_Mark : constant String := " and ";

   function Row_Fits (L : Window_Log; P : Number_List) return Boolean
   is (P.Ok
       and then P.Count = L.Series
       and then Is_Data (P.Values (1 .. P.Count))
       and then L.Given < Max_Rows);

   --  Whether every row of a rows step fits the window.
   function Rows_Fit (Ctx : Step_Context) return Boolean is
      Text : constant String := Fabula.Args.Text (Ctx.A, 1);
      L    : Window_Log := Log (Ctx);
      From : Positive := Text'First;
      Stop : Positive;
   begin
      while From <= Text'Last loop
         Stop := Next_Mark (Text, Row_Mark, From);
         if not Row_Fits (L, Parse_List (Text (From .. Stop - 1))) then
            return False;
         end if;
         L.Given := L.Given + 1;
         From := Stop + Row_Mark'Length;
      end loop;
      return True;
   end Rows_Fit;

   procedure Log_Row (Ctx : in out Step_Context; Text : String) is
      P : constant Number_List := Parse_List (Text);
      L : Window_Log renames Ctx.W.Stats.Window;
   begin
      L.Given := L.Given + 1;
      L.Rows (L.Given) (1 .. L.Series) := P.Values (1 .. L.Series);
   end Log_Row;

   procedure Log_Rows (Ctx : in out Step_Context) is
      Text : constant String := Fabula.Args.Text (Ctx.A, 1);
      From : Positive := Text'First;
      Stop : Positive;
   begin
      while From <= Text'Last loop
         Stop := Next_Mark (Text, Row_Mark, From);
         Log_Row (Ctx, Text (From .. Stop - 1));
         From := Stop + Row_Mark'Length;
      end loop;
   end Log_Rows;

   function Series_Of (Ctx : Step_Context) return Natural
   is (Natural (Units_Of (Ctx)));

   function Names_Series (Ctx : Step_Context; N : Positive) return Boolean
   is (Units_Read (Ctx, N)
       and then Units_Of (Ctx, N) in 1 .. Abacus.Raw (Log (Ctx).Series));

   function Pair_Fits (Ctx : Step_Context) return Boolean
   is (Names_Series (Ctx, 1)
       and then Names_Series (Ctx, 2)
       and then Log (Ctx).Given - Log (Ctx).Removed >= 2);

   function Is_Method (Ctx : Step_Context) return Boolean
   is (for some M in Method =>
         Lower (M'Image) = Lower (Fabula.Args.Word (Ctx.A, 2)));

   ---------------------------------------------------------------------
   --  The machine.
   ---------------------------------------------------------------------

   function Evaluate
     (G : Guard_Kind; Ctx : Step_Context; Evt : Step_Kind) return Boolean
   is
      pragma Unreferenced (Evt);
   begin
      return
        (case G is
           when Always         => True,
           when Data_Read      => List_Of (Ctx).Ok,
           when Quantile_Named =>
             Decimal_Read (Ctx)
             and then Decimal_Of (Ctx) in Probability
             and then Is_Method (Ctx),
           when Answer_Read    => Decimal_Read (Ctx),
           when Near_Read      =>
             Decimal_Read (Ctx, 1) and then Decimal_Read (Ctx, 2),
           when Computable     => Is_Statistic (Ctx) and then Ready (Ctx),
           when Series_Read    =>
             Units_Read (Ctx) and then Units_Of (Ctx) in 1 .. Max_Series,
           when Rows_Read      => Rows_Fit (Ctx),
           when Row_Read       => Row_Fits (Log (Ctx), List_Of (Ctx)),
           when Removable      => Log (Ctx).Removed < Log (Ctx).Given,
           when Pair_Read      => Pair_Fits (Ctx));
   end Evaluate;

   procedure Quantile_Of (Ctx : in out Step_Context) is
      Sorted : Long_Vector := Long_Vector (Held (Ctx));
      Order  : Order_Array (Sorted'Range);
   begin
      Sort (Sorted, Order);
      Ctx.W.Stats.Answer :=
        Quantile
          (Sorted,
           Decimal_Of (Ctx),
           Method'Value (Fabula.Args.Word (Ctx.A, 2)));
   end Quantile_Of;

   procedure Give (A : Give_Action; Ctx : in out Step_Context) is
      T : Table renames Ctx.W.Stats;
   begin
      case A is
         when A_Give         =>
            T :=
              (Data   => List_Of (Ctx).Values,
               Count  => List_Of (Ctx).Count,
               others => <>);

         when A_Give_Weights =>
            T.Weights := List_Of (Ctx).Values;
            T.Weighed := List_Of (Ctx).Count;

         when A_Give_Second  =>
            T.Second := List_Of (Ctx).Values;
            T.Paired := List_Of (Ctx).Count;

         when A_Quantile     =>
            Quantile_Of (Ctx);

         when A_Compute      =>
            T.Answer := Compute (Ctx);

         when A_Open         =>
            T.Window := (Series => Series_Of (Ctx), others => <>);

         when A_Give_Rows    =>
            Log_Rows (Ctx);

         when A_Add          =>
            Log_Row (Ctx, Fabula.Args.Text (Ctx.A, 1));

         when A_Remove       =>
            T.Window.Removed := T.Window.Removed + 1;
      end case;
   end Give;

   --  Series I's and J's sample covariance in the slid and the fresh
   --  window agree.
   function Covariances_Agree (Ctx : Step_Context) return Boolean is
      I : constant Index := Index (Units_Of (Ctx, 1));
      J : constant Index := Index (Units_Of (Ctx, 2));
   begin
      return
        Rolling.Covariance (Slid (Log (Ctx)), I, J, Sample)
        = Rolling.Covariance (Fresh (Log (Ctx)), I, J, Sample);
   end Covariances_Agree;

   procedure Check (A : Check_Action; Ctx : in out Step_Context) is
      Answer : constant Val := Ctx.W.Stats.Answer;
   begin
      case A is
         when A_Check_Answer     =>
            Fabula.Check.Text_Equal
              (Ctx.R,
               Abacus.Text.Image (Answer),
               Abacus.Text.Image (Decimal_Of (Ctx)),
               "the answer");

         when A_Check_Near       =>
            Fabula.Check.Is_True
              (Ctx.R,
               abs (Answer - Decimal_Of (Ctx, 2)) <= Decimal_Of (Ctx, 1),
               "the answer is " & Abacus.Text.Image (Answer));

         when A_Check_Fresh      =>
            Fabula.Check.Is_True
              (Ctx.R,
               Slid (Log (Ctx)) = Fresh (Log (Ctx)),
               "the slid window's sums differ from a fresh window's");

         when A_Check_Covariance =>
            Fabula.Check.Is_True
              (Ctx.R,
               Covariances_Agree (Ctx),
               "the slid window's covariance differs from a fresh one's");
      end case;
   end Check;

   --  Why a step was refused.
   function Refusal (A : Refuse_Action; Ctx : Step_Context) return String
   is (case A is
         when A_Refuse_Data     =>
           "data are up to"
           & Max_Data'Image
           & " decimal numbers separated by commas",
         when A_Refuse_Quantile =>
           "a quantile is a number from 0 to 1, by the nearest or the linear"
           & " rule",
         when A_Refuse_Answer   => "the answer is checked against numbers",
         when A_Refuse_Compute  =>
           "cannot compute the "
           & Said (Ctx)
           & ": the statistics are mean, weighted mean, population or sample"
           & " variance, standard deviation or covariance, and correlation,"
           & " with the weights or the second series given",
         when A_Refuse_Empty    => "no data have been given",
         when A_Refuse_Window   =>
           "a window is over 1 to" & Max_Series'Image & " series",
         when A_Refuse_Row      =>
           "a row has one number of at most 256 per series, and a window"
           & " takes at most"
           & Max_Rows'Image
           & " rows",
         when A_Refuse_Remove   => "the window holds no row to remove",
         when A_Refuse_Pair     =>
           "a covariance names two of the window's series, over at least two"
           & " rows");

   procedure Execute
     (A : Action_Kind; Ctx : in out Step_Context; Evt : Step_Kind)
   is
      pragma Unreferenced (Evt);
   begin
      case A is
         when A_Nothing     =>
            null;

         when Give_Action   =>
            Give (A, Ctx);

         when Check_Action  =>
            Check (A, Ctx);

         when Refuse_Action =>
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

   Give_Data              : constant Ev := (Kind => E_Give_Data);
   Take_Quantile          : constant Ev := (Kind => E_Take_Quantile);
   Check_Answer           : constant Ev := (Kind => E_Check_Answer);
   Give_Weights           : constant Ev := (Kind => E_Give_Weights);
   Give_Second            : constant Ev := (Kind => E_Give_Second);
   Compute_Ev             : constant Ev := (Kind => E_Compute);
   Check_Near             : constant Ev := (Kind => E_Check_Near);
   Open_Window            : constant Ev := (Kind => E_Open_Window);
   Give_Rows              : constant Ev := (Kind => E_Give_Rows);
   Add_Row                : constant Ev := (Kind => E_Add_Row);
   Remove_Oldest          : constant Ev := (Kind => E_Remove_Oldest);
   Check_Fresh            : constant Ev := (Kind => E_Check_Fresh);
   Check_Fresh_Covariance : constant Ev := (Kind => E_Check_Fresh_Covariance);

   --!format off
   Table_Rows : constant Transition_Table :=
     [Empty    + Give_Data              (Data_Read)      / A_Give             >= Holding,
      Empty    + Give_Data                               / A_Refuse_Data      >= Empty,
      Empty    + Open_Window            (Series_Read)    / A_Open             >= Windowed,
      Empty    + Open_Window                             / A_Refuse_Window    >= Empty,
      Empty    + Take_Quantile                           / A_Refuse_Empty     >= Empty,
      Empty    + Compute_Ev                              / A_Refuse_Empty     >= Empty,
      Empty    + Check_Answer                            / A_Refuse_Empty     >= Empty,
      Holding  + Give_Data              (Data_Read)      / A_Give             >= Holding,
      Holding  + Give_Data                               / A_Refuse_Data      >= Holding,
      Holding  + Give_Weights           (Data_Read)      / A_Give_Weights     >= Holding,
      Holding  + Give_Weights                            / A_Refuse_Data      >= Holding,
      Holding  + Give_Second            (Data_Read)      / A_Give_Second      >= Holding,
      Holding  + Give_Second                             / A_Refuse_Data      >= Holding,
      Holding  + Take_Quantile          (Quantile_Named) / A_Quantile         >= Answered,
      Holding  + Take_Quantile                           / A_Refuse_Quantile  >= Holding,
      Holding  + Compute_Ev             (Computable)     / A_Compute          >= Answered,
      Holding  + Compute_Ev                              / A_Refuse_Compute   >= Holding,
      Answered + Give_Data              (Data_Read)      / A_Give             >= Holding,
      Answered + Give_Data                               / A_Refuse_Data      >= Answered,
      Answered + Take_Quantile          (Quantile_Named) / A_Quantile         >= Answered,
      Answered + Take_Quantile                           / A_Refuse_Quantile  >= Answered,
      Answered + Compute_Ev             (Computable)     / A_Compute          >= Answered,
      Answered + Compute_Ev                              / A_Refuse_Compute   >= Answered,
      Answered + Check_Answer           (Answer_Read)    / A_Check_Answer     >= Answered,
      Answered + Check_Answer                            / A_Refuse_Answer    >= Answered,
      Answered + Check_Near             (Near_Read)      / A_Check_Near       >= Answered,
      Answered + Check_Near                              / A_Refuse_Answer    >= Answered,
      Windowed + Give_Rows              (Rows_Read)      / A_Give_Rows        >= Windowed,
      Windowed + Give_Rows                               / A_Refuse_Row       >= Windowed,
      Windowed + Add_Row                (Row_Read)       / A_Add              >= Slid,
      Windowed + Add_Row                                 / A_Refuse_Row       >= Windowed,
      Windowed + Remove_Oldest          (Removable)      / A_Remove           >= Slid,
      Windowed + Remove_Oldest                           / A_Refuse_Remove    >= Windowed,
      Slid     + Add_Row                (Row_Read)       / A_Add              >= Slid,
      Slid     + Add_Row                                 / A_Refuse_Row       >= Slid,
      Slid     + Remove_Oldest          (Removable)      / A_Remove           >= Slid,
      Slid     + Remove_Oldest                           / A_Refuse_Remove    >= Slid,
      Slid     + Check_Fresh                             / A_Check_Fresh      >= Slid,
      Slid     + Check_Fresh_Covariance (Pair_Read)      / A_Check_Covariance >= Slid,
      Slid     + Check_Fresh_Covariance                  / A_Refuse_Pair      >= Slid];
   --!format on

   Current : State := Empty;

   procedure Offer
     (Ctx : in out Step_Context; Evt : Step_Kind; Handled : out Boolean) is
   begin
      Flow.Take (Table_Rows, Current, Ctx, Evt, Handled);
   end Offer;

   procedure Reset is
   begin
      Current := Empty;
   end Reset;

   function Phase return String
   is (Current'Image);

end Abacus_Steps.Stats;
