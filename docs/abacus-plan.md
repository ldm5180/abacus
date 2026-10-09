# abacus plan

**Status (2026-10-06):** S0 done on branch `spike` (`spike/`):
**go**, with scaled 64-bit integers at `Frac = 40` (section 2).  A1-A12
built on `main`, every unit proved at level 2 with no assumption, the
seven features green in both modes.  Two follow-ups since: the sort is
a merge sort over up to 2**30 elements, and the solver polishes, which
certifies the tail-mean (CVaR-shaped) linear program that plain ADMM
could not (A10's note, now closed).  Three iterations of the plan, S0's
note, the implementation's, then the follow-ups' (see Revision notes).
A13 (second-order cones in the solver) and A14 (scrambled Sobol
sequences) were added for statera's first consumer; see their items and
their revision note.  **(2026-10-08)** A15 (statera's W12b): the solver
certifies the homogenized ratio program, which it never did on real
data, and most mean-CVaR programs it did not; built, with a design
choice left open for the near-degenerate linear programs (A15's Built
note), which the user then made: A16, a crossover to a vertex for a
linear program, built; every mean-CVaR program of the user's data now
certifies.

abacus is fixed-point numerics for Ada 2022, proved in SPARK:
arithmetic on scaled integers, text and IEEE conversion, elementary
functions, statistics, dense linear algebra, and a solver for
quadratic programs.  No floating-point type appears anywhere in it.
It has no dependencies.  Its first consumer is statera
(`~/git/statera/docs/statera-plan.md`, the master plan), and nothing
in it knows about trading.

The name is the counting board: arithmetic done with whole beads.

## How to use this plan

**S0 comes first and can stop everything.**  It is a spike with four
go/no-go criteria.  If any fails, write the numbers into section 2,
stop, and take them to the user.  A1 onward assume S0's verdict; the
sketches below are written for the outcome expected, and S0's notes
say what to change if it lands elsewhere.

After S0, work A1-A12 in order.  Each item is one or more TDD cycles
(RED first), logged in `docs/tdd-log.md`, one commit per cycle,
`make ci` after each.  Every unit is in `src/` with `SPARK_Mode`;
`make prove` is owed by every item.

Each item has five parts: **Where**, **What is wrong** (here, what
is missing, or what the usual floating-point way costs), **Why**,
**Fix**, **RED first**.

### Do not

- Do not declare or name a floating-point type.  `make no-float` is
  in `make ci`.
- Do not use `pragma Assume`, and do not turn `SPARK_Mode` off.  If
  a proof will not go through, bound the input (see below) or
  return a typed outcome.
- Do not state a bound on the result of a nonlinear operation and
  hope the prover finds it.  Bound the operands with subtypes;
  graecus measured one unclamped operand at 89,000 proof steps
  against 4,000 for the whole unit once clamped
  (`~/git/graecus/docs/fixed-point-spike.md`).
- Do not write `abs X` on an unconstrained integer; state ranges.
- Do not raise from the library.  Every operation that can fail
  returns an outcome that names how.
- Do not add a dependency.
- Do not test against "the true value" where an approximation is
  involved; test against the approximation's own definition, and
  against an oracle fixture within the grid's resolution.
- Do not put trading words in a name or a comment.

## 1. Shape

### 1.1 The representation S0 is expected to choose

A value is a 64-bit integer counting units of 2^-40
(`Frac = 40`): range about +-8.3 million, resolution about 9e-13.
A product of two values is formed in a 128-bit integer
(`Long_Long_Long_Integer`) and shifted once.  A sum of products is
accumulated at 128 bits and shifted once at the end, so a dot
product of any length has one rounding.

```ada
package Abacus with SPARK_Mode, Pure is

   Frac : constant := 40;
   One  : constant := 2 ** Frac;

   type Raw  is range -2 ** 63 .. 2 ** 63 - 1 with Size => 64;
   type Wide is range -2 ** 127 .. 2 ** 127 - 1 with Size => 128;

   --  A value whose magnitude is at most one: a correlation, a
   --  standardized direction, a weight.
   subtype Unit_Raw is Raw range -One .. One;

end Abacus;
```

Consumers wrap `Raw` in private types per quantity; abacus offers a
generic for that (`Abacus.Quantities`).

### 1.2 Units

| unit | holds |
|---|---|
| `Abacus` | `Raw`, `Wide`, the scale |
| `Abacus.Arith` | multiply, divide, round, saturate, with outcomes |
| `Abacus.Quantities` | a generic giving a consumer a private typed quantity |
| `Abacus.Text` | decimal text to value and back |
| `Abacus.Ieee` | IEEE-754 bit patterns to value |
| `Abacus.Elementary` | square root, exp, log, normal CDF and its inverse |
| `Abacus.Vectors` | dot, axpy, sums, norms |
| `Abacus.Sorting` | sort, rank, quantile |
| `Abacus.Stats` | weighted mean, variance, covariance, correlation, moments, rolling sums |
| `Abacus.Matrices` | dense and symmetric storage, products |
| `Abacus.Cholesky` | factor, solve, least squares |
| `Abacus.Qp` | the QP problem, the solver, the certificate |
| `Abacus.Random` | a seeded integer generator |
| `Abacus.Qp.Cones` | the second-order cone: norm, projection, how far outside |
| `Abacus.Sobol` | scrambled Sobol sequences |
| `Abacus.Qp.Scaling` | equilibration, as a step per row and variable and the scales of the matrix factored |
| `Abacus.Qp.Held` | the problem with a set of bounds held: read off an iterate, solved for a cost given, its square system both ways, its dependences, a vertex |
| `Abacus.Qp.Crossover` | a linear program walked by pivots from the held set to a certified vertex |
| `Abacus.Qp.Picks` | the constraints a held set picks to change |

### 1.3 What is proved

Absence of run-time errors everywhere.  Functional contracts where
they are cheap and worth having: a sort returns a sorted permutation;
a quantile is an element of its input; a projection lies in its
box; `Certified` means what its expression function says.  The
solver's algorithm is not proved to converge; its answer is checked,
and the check is proved.

## 2. S0's verdict

**Go.**  Representation (b), 64-bit scaled integers with a 128-bit
accumulator, at `Frac = 40`, meets all four bars.  `Frac = 48` meets
them too; `Frac = 32` reaches the accuracy but cannot certify it, and
so misses the speed bar as configured.  Representation (a), Ada
`delta` types, was measured through the kernels and stopped there
(below, "Why not (a)").

| criterion | bar | (b) Frac 32 | (b) Frac 40 | (b) Frac 48 |
|---|---|---|---|---|
| proof | every check proves at level 2, whole run under 10 minutes | all proved | all proved | all proved |
| accuracy | weights within 1e-6 of the oracle's | within 1e-6 at iteration 110; floor 4.4e-8; **not certifiable**: the residuals' floor (primal 7-10 units, 2.3e-9) lies above the tolerance that implies 1e-6, so the solve runs to its cap | within 1e-6 at iteration 110; the solver's own rule stops at 140 with 7.1e-8; floor 2.2e-10 | within 1e-6 at 110; rule stops at 140 with 7.1e-8; floor 7.5e-13 |
| speed, one bucket | estimate, factor and solve under 100 ms | **115.0 ms** (93.8 unchecked): 4,000 iterations, Exhausted | **7.21 ms** (5.57 unchecked), 140 iterations, Converged | 7.22 ms (5.67 unchecked) |
| speed, large | factor a 3,000 x 3,000 matrix under 60 s | 3.52 s (3.18 unchecked) | **3.57 s** (3.22 unchecked) | 3.53 s (2.99 unchecked) |

The proof row is one run over every spike unit at all three grids,
representation (a)'s kernels included: **2,842 checks, all proved,
1 min 40 s wall from a clean `proof/obj`** (gnatprove 15, `--level=2
--checks-as-errors=on -j0`, 12 cores, 320 MB).  The hardest single
check took 5,176 steps and 0.1 s (`Spike.Deltas.Quotient`); in (b)
none took more than 2,195.  No `pragma Assume`, no `SPARK_Mode Off`
in any spike unit; the tests, the benchmark and the fixture reader
are not SPARK (AUnit, files, a clock, the heap).

**How the numbers were made.**  `spike/bench`, two profiles, both
`-O3 -gnatn`: *release* keeps the language checks (no `-gnata`),
*unchecked* adds `-gnatp`, removing every check the proof discharges.
One thread.  Each profile was run twice and the second run kept
(`spike/bench/results/`); the bucket is the best of five
`Solve_Bucket` calls.  Between runs the 3,000 factor moved by up to
about 10% (3.52 s and 3.98 s at Frac 32), the bucket by under 1%.  At
Frac 40 the bucket splits as estimate 2.59
ms (1.89), form and factor 0.87 ms (0.69), solve 4.69 ms (3.82, its
own factor included).  The iteration traces are byte-identical in both
profiles.

**The bucket and the oracle.**  `spike/tools/make_bucket.py`, seed
20261006: 180 assets in two blocks of 90, 250 days; the sample's
median correlation is 0.7345 within a block and -0.3142 between
(population 0.73 and -0.26), returns' mean 0.0015 (population 0.005,
the sample's common factor pulled it down), std 0.053, min -0.35.
The problem is PRO's: minimize (1/2) w'(20 S + 1e-6 I) w - mu'w,
0 <= w <= 1, each block summing to 0.10, S the sample covariance.  The
oracle (OSQP, eps 1e-9, polished, 325 iterations) holds three assets;
Clarabel agrees to within 1.2e-12 and an exact KKT solve on OSQP's
active set to within 6e-16, with every multiplier sign right.  Returns and answers are
written as raw integers at each grid, from returns already rounded to
that grid.

**How the Ada side forms its inputs** (statera follows this):

1. Returns are held one row per asset.  Each row is centered on its
   mean (one rounding), its variance summed exactly at scale
   `One * One` and divided by n - 1.
2. The deviation is the integer root of the variance *raised by fours
   while it fits* (up to 20 extra bits), and the inverse deviation is
   taken from that lifted root.  Without the lift a deviation near
   0.05 rounded at 2^-32 is good to only 2.5e-9, which put the
   correlation's diagonal about 20 units off.  With it, means and
   deviations are within 1 unit of numpy's and two correlation rows
   within 4, at every grid.
3. Each row becomes its z-scores in place; the correlation is
   `Z Z' / (n - 1)`, one rounding per entry.  The covariance never
   exists as a matrix.
4. The problem is solved in correlation space, `x = sigma w`:
   `P = C + ridge / (lambda sigma^2)`, `q = -mu / (lambda sigma)`, box
   `0 .. cap sigma`, and each block's row `sum x / sigma = budget`
   divided through by the row's length.  `P` has a unit diagonal and
   entries in -1 .. 1.  Weights come back as `w = x / sigma`, with the
   same inverse deviation the z-scores used, so the change of
   variables is exact whatever that inverse's rounding.

The same problem formed in the weights themselves (covariance space)
also reaches 1e-6, at 540 iterations against 110, with the rule
stopping at about 1,015 and a lower floor (30-48 units).  Correlation
space buys four to five times fewer iterations; the accuracy does not
depend on it.

**The ADMM, as measured.**  A10's method, OSQP's relaxed step:
`P + sigma I + rho I + rho_row E'E` factored once; rho = 1, rho_row =
2^3, sigma = 2^-20, alpha = 1.6; residuals checked every 10
iterations; tolerances 1e-10 (primal) and 1e-9 (dual) as values, the
same at every grid.  Every step size is a power of two, so applying
one is a shift.  ADMM did not stall short of 1e-6 at any grid, so none
of the fallbacks was needed: correlation space was the starting
formulation, and **polish and the dual active-set method were not
built**.  Sweeping rho_row from 2^2 to 2^10 moved the iterations to
1e-6 only between 110 and 150; 2^3 was fastest.

**Why not (a).**  Its kernels are not slower where the time goes: a
product accumulated into a type whose Small is the square of the
operands' needs no rescale, and `objdump` shows the dot loop with no
call (0.78 ns per term against (b)'s 0.49 with checks, 0.33 for both
under `-gnatp`).  The 3,000 factor is 4.92 s (3.01 unchecked) against
(b)'s 3.57 s (3.22), inside the bar.  What decides it:

- the per-element step ADMM takes on every iteration, a product
  rescaled to its operands' grid, is **11.7 ns in (a) against 1.06 ns
  in (b)** (11.5 against 0.60 unchecked): graecus's finding holds for
  this operation and no other;
- SPARK refuses `Fix'Round` of a quotient ("not yet supported", and
  the quotient is `root_real`), so every rounded quotient is truncated
  and corrected by its remainder, one more product each;
- a raw 64-bit integer cannot enter a `delta` value in SPARK:
  `'Fixed_Value` is refused, `Fix'Small * Integer` takes only a
  32-bit `Integer`, and converting the integer to `Fix` first
  overflows (only the way out, `X / Fix'Small` to an integer, is
  accepted);
- a `delta` type's Small must be static, so (a) needs its types
  declared per grid, where (b) is one generic over `Frac`.

**What took more than a loop invariant and a subtype to prove.**
Nothing needed an assumption or a lemma; these needed a shape:

- `Shifted` (a value times 2^s): its result had no bound, and 30
  overflow checks downstream failed.  The power comes from a table
  whose element subtype is `1 .. 2^30`, plus a postcondition on
  `Shifted` -- bounding the input, as graecus found.
- The lifted root: four-power and two-power counters that the prover
  could not relate are bounded instead by explicit exit tests in the
  loop.
- Pivots are a positive subtype in both representations; (a) first
  had a quantified invariant over the pivots, which did not prove.
- (a) needed a precondition on the instance (`Roomy`: the
  accumulator holds Max_N products plus a value) and accumulator
  ranges at 1.5 times the largest dot product.
- `Store`, the checked narrowing every step goes through, carries a
  postcondition.
- Two tool limits, rewritten around: gnatprove's frontend refused an
  if-expression returning aggregates in an inlined function ("cannot
  untangle node N_IF_EXPRESSION"); `Fix'Round` as above.
- The integer root's `R * R <= X` invariant, nonlinear, proved with no
  help.

## 3. Items

### S0 -- The spike: one real-sized bucket, in fixed point

- **Where:** a branch `spike`; `spike/` in the repository, not
  `src/`.  Kept afterwards as the record.
- **What is wrong:** nobody has run a factorization and an
  iterative QP solve in fixed point under SPARK at this size.
  Three things are unknown: whether the proofs go through without
  heroics, whether rounding stalls the iteration short of a useful
  answer, and what representation is fast enough.
- **Why:** graecus settled fixed point for scalar formulas, not for
  linear algebra.
- **Fix:** build, in the spike only:
  1. Two representations of the same value: (a) Ada `delta` types
     with `Small => 2.0 ** (-Frac)`, a 128-bit `delta` accumulator;
     (b) scaled integers as in section 1.1.  A dot product in
     representation (a) already proves (statera plan, section 1).
  2. For each: a dot product, a symmetric rank update, a Cholesky
     factorization of a correlation matrix plus a ridge, two
     triangular solves, and the ADMM iteration of A10 with a fixed
     iteration cap.
  3. A synthetic bucket from `tools/make_bucket.py` (numpy, seeded):
     180 assets in two blocks of 90 with within-block correlation
     0.73 and between-block correlation -0.26, 250 days; and the
     oracle's answer (OSQP at 1e-9, then polished) for a
     mean-variance problem with a budget and caps.
  4. Measure the four criteria of section 2 for `Frac` in 32, 40
     and 48.
- **Go / no-go:** all four bars met by one representation at one
  `Frac`.  Record the table, the choice, and any proof that needed
  more than a loop invariant and a subtype.  If the iteration
  stalls, try in this order and record each: scaling the problem to
  unit diagonal; a larger `Frac`; the polish step of A10; a dual
  active-set method in place of ADMM.  If none meets the bars, stop.
- **RED first:** `spike/tests`: the fixed-point weights equal the
  oracle's to 1e-6.  It fails because nothing computes them.
- **Gates:** the verdict table, filled in; a note to the user.

### A1 -- The skeleton

- **Where:** `~/git/abacus`.  Template: `~/git/graecus` at `cddb356`
  for the flat `src/` layout and `bench/`; `~/git/lector` at
  `dd92622` for CI (toolchain pin, cache, `--validation`, the
  features report).
- **What is wrong:** nothing exists.
- **Why:** new.
- **Fix:** crate `abacus`, `abacus.gpr`, `proof/proof.gpr` that
  withs nothing, `tests/test_abacus.gpr` with two mains, Makefile
  targets `build test features features-report prove format
  validation no-float bench ci`, the `Flows` runner copied to
  `tests/src/abacus_steps-flows.ads/.adb`, MIT license, `CLAUDE.md`.
- **RED first:** `make features` has no rule; then one undefined
  step in `arithmetic.feature`.
- **Gates:** `make ci`.
- **Done:** crate, gprs, Makefile (with `shape`, the fructus shape lint adapted, and a comment-blind `no-float`), CI, the Flows runner, CLAUDE.md, MIT license.

### A2 -- Arithmetic with outcomes

- **Where:** `src/abacus.ads`, `src/abacus-arith.ads/.adb`,
  `src/abacus-quantities.ads`.
- **What is wrong:** floating point rounds each operation by a rule
  that depends on magnitude, and overflow becomes an infinity that
  travels.
- **Why:** IEEE.
- **Fix:** `Mul (A, B : Raw) return Raw` with a precondition that
  the product fits, proved from operand subtypes at the call sites;
  `Mul_Sat` and `Div_Sat` that saturate inside the wide
  intermediate and say so; rounding to nearest, ties away from
  zero, as one named function.  `Quantities` is a generic over a
  name that yields a private type with `+`, `-`, comparison, and
  conversions the consumer chooses to expose.

  ```ada
  function Mul (A, B : Raw) return Raw
  with
    Pre  => Fits (Wide (A) * Wide (B)),
    Post => Mul'Result = Raw (Round_Shift (Wide (A) * Wide (B)));
  ```
- **RED first:** `Abacus_Arith_Tests.Test_Half_Times_Half`:
  `Mul (One / 2, One / 2) = One / 4`.  Fails to compile.
- **Gates:** `make ci`, `make prove`.
- **Done:** `Abacus` (with `Val`, `Vector`, `Matrix`), `Abacus.Arith` (`Div_Round` the one rounding, `Mul`, `Div`, `Mul_Sat`, `Div_Sat`, `Store`, `Powers_Of_Two`), `Abacus.Quantities` (a generic over a range), arithmetic.feature.

### A3 -- Decimal text

- **Where:** `src/abacus-text.ads/.adb`.
- **What is wrong:** every number in a config, a CSV or a report is
  decimal text; converting through a float adds an error that is
  not the grid's.
- **Why:** it is the easy way.
- **Fix:** `Parse (Text) return Read` where `Read` is `(Ok, Value,
  Error)`: an optional sign, digits, an optional fraction, an
  optional exponent; the result is the nearest grid value.
  `Image (Value, Places)` writes the shortest text of at most
  `Places` places that parses back to `Value` when `Places` is
  large enough.  Parsing is an sml scanner, as tempus's RFC 3339
  reader is.
- **RED first:** `text.feature`, "0.2621 reads and writes back as
  0.2621".
- **Gates:** `make ci`, `make prove`.
- **Done:** `Abacus.Text` with its sml scanner `Abacus.Text.Scanner`; exact rounding of any length of fraction; `Image` at the fewest places up to 20; text.feature.

### A4 -- IEEE bit patterns

- **Where:** `src/abacus-ieee.ads/.adb`.
- **What is wrong:** data files hold binary64 and binary32 numbers,
  and the usual way to read one is to reinterpret the bytes as a
  float, which is outside SPARK's value model and puts a float in
  the program.
- **Why:** it is one line.
- **Fix:** `From_Binary64 (Bits : Unsigned_64) return Read` and
  `From_Binary32`: take the sign, exponent and mantissa apart as
  integers, shift the mantissa to the grid, round to nearest.
  Outcomes: `Ok`, `Not_A_Number`, `Infinite`, `Out_Of_Range`.
  Subnormals and zero are `Ok`.
- **RED first:** `ieee.feature`, "The bits of -120.0 read as -120".
- **Gates:** `make ci`, `make prove`.
- **Done:** `Abacus.Ieee`; ieee.feature.

### A5 -- Elementary functions

- **Where:** `src/abacus-elementary.ads/.adb`.  Source: graecus
  branch `fixed-point-spike`, `src/graecus-fixed.ads/.adb`.
- **What is wrong:** square root, exp, log and the normal CDF are
  needed (annualizing, decay weights, compound returns, the
  deflated Sharpe ratio), and the library versions are float.
- **Why:** there has been no fixed-point home for them.
- **Fix:** lift graecus's proved `Sqrt`, `Exp`, `Log` and
  `Norm_Cdf`, rescale to this crate's `Frac`, and keep its traps in
  mind (the closing step of a normalize chain; clamps derived from
  the seed's error).  Add `Inv_Norm_Cdf` by a rational
  approximation with a stated error.  Each has a bounded domain as
  a subtype.
- **RED first:** `elementary.feature`, "The square root of 2,
  squared, is 2 to the grid".
- **Gates:** `make ci`, `make prove`.
- **Done:** `Abacus.Elementary`: `Root`, `Sqrt`, `Exp`, `Log`, `Norm_Cdf`, `Inv_Norm_Cdf` (AS 241); `tools/make_elementary.py`; elementary.feature.

### A6 -- Vectors

- **Where:** `src/abacus-vectors.ads/.adb`.
- **What is wrong:** a float sum depends on the order of its terms,
  so two runs that read files in a different order differ in the
  last places, and so do one task and eight.
- **Why:** float addition is not associative.
- **Fix:** `Dot`, `Axpy`, `Sum`, `Norm_Inf`, `Scale` over arrays of
  `Raw`.  `Dot` accumulates at 128 bits and rounds once; its
  contract bounds the result by the length times the operand
  bounds.  Sums are exact, so order cannot matter.
- **RED first:** `Abacus_Vectors_Tests.Test_Dot_Is_Order_Free`: a
  dot product and the same with both vectors reversed are equal,
  exactly, for 4,096 seeded elements.
- **Gates:** `make ci`, `make prove`.
- **Done:** `Abacus.Vectors`.

### A7 -- Sorting and quantiles

- **Where:** `src/abacus-sorting.ads/.adb`.
- **What is wrong:** PRO's quantiles are Polars' "nearest" rule,
  its ranks break ties by an accident of string interning.
- **Why:** defaults.
- **Fix:** a proved sort (the result is sorted and is a permutation
  of the input), stable, with a caller's tie-break key; `Rank`;
  `Quantile (Sorted, Q, Method)` with `Nearest` (PRO's rule: the
  element at index round-half-away(q (n - 1))) and `Linear`.
- **RED first:** `stats.feature`, "The median of 1, 2, 3, 4 by the
  nearest rule is 3".
- **Gates:** `make ci`, `make prove`.
- **Done:** `Abacus.Sorting`: insertion over an order array, proved a sorted permutation in the order value, key, place; then a merge sort over `Long_Vector` (see the follow-ups note).

### A8 -- Statistics

- **Where:** `src/abacus-stats.ads/.adb`,
  `src/abacus-stats-rolling.ads/.adb`.
- **What is wrong:** a covariance over a window that slides is
  recomputed from scratch each time, because updating a float sum
  by adding and subtracting drifts.
- **Why:** float.
- **Fix:** weighted mean, variance, covariance and correlation from
  sums and sums of products held at 128 bits; skewness and
  kurtosis on standardized values; `Rolling` holds the sums for a
  window and offers `Add_Row` and `Remove_Row`, exact, so a slid
  window's sums equal a fresh computation bit for bit.  Sample and
  population divisors are a parameter.
- **RED first:** `stats.feature`, "A slid window equals a fresh
  one".
- **Gates:** `make ci`, `make prove`.
- **Done:** `Abacus.Stats` (with the spike's `Standardize` and `Correlate`) and `Abacus.Stats.Rolling`; stats.feature.

### A9 -- Matrices and Cholesky

- **Where:** `src/abacus-matrices.ads/.adb`,
  `src/abacus-cholesky.ads/.adb`.
- **What is wrong:** a matrix with more columns than rows of data
  is singular, and a float factorization of it returns numbers
  anyway.
- **Why:** a tiny pivot is still a number.
- **Fix:** dense row-major storage with bounds as discriminants; a
  symmetric matrix type; `Factor` returns `(Factored, L)` or
  `Not_Positive_Definite` with the failing column, deciding by a
  pivot floor the caller sets; every entry of `L` is checked into
  its range before it is stored, so the next column's proof has its
  bound.  `Solve` does the two triangular solves.
  `Least_Squares (X, Y)` solves the normal equations with a ridge.
- **RED first:** `cholesky.feature`, "A matrix with a repeated
  column is refused, and the column is named".
- **Gates:** `make ci`, `make prove`.
- **Done:** `Abacus.Matrices` (the spike's kernels, inlined) and `Abacus.Cholesky` (with `Least_Squares`); cholesky.feature.

### A10 -- The QP solver

- **Where:** `src/abacus-qp.ads/.adb`, `-engine.ads/.adb`,
  `-certificate.ads/.adb`.
- **What is wrong:** the usual solver is a library whose answer is
  trusted, and whose failure is a status string.
- **Why:** it is a library.
- **Fix:** the problem is: minimize `(1/2) x'P x + q'x` subject to
  `l <= A x <= u`, with `P` symmetric positive semidefinite.
  - The method is ADMM in the operator-splitting form: factor
    `P + s I + r A'A` once; each iteration solves for `x` with that
    factor, projects `A x + y / r` onto `[l, u]` to get `z`, and
    updates `y`.  `z` lies in its box by construction, which is
    what the range proofs hold on to; `x` and `y` are checked into
    range after each step, and leaving it is the outcome
    `Diverged`.
  - The loop is an sml machine: `Iterating`, `Converged`,
    `Polished`, `Certified`, `Infeasible`, `Exhausted`, `Diverged`.
    The iteration cap makes termination a fact.
  - Polish: take the constraints active at the answer, solve the
    equality-constrained problem exactly with `Cholesky`, keep the
    result only if the certificate improves.
  - The certificate, an expression function over the problem and
    the answer: primal residual, dual residual and complementarity
    each within a tolerance, computed at 128 bits.

  ```ada
  type Outcome is
    (Certified, Infeasible, Exhausted, Diverged, Not_Convex);

  function Certified
    (P : Problem; X : Vector; Y : Vector; Tol : Tolerance)
     return Boolean
  is (Primal_Residual (P, X) <= Tol.Primal
      and then Dual_Residual (P, X, Y) <= Tol.Dual
      and then Complementarity (P, X, Y) <= Tol.Gap);

  procedure Solve
    (P : Problem; Start : Vector; S : Settings;
     X : out Vector; Y : out Vector; Result : out Outcome)
  with Post => (if Result = Certified then Certified (P, X, Y, S.Tol));
  ```
  - A linear program is the case `P = 0`.  A warm start is `Start`.
- **RED first:** `qp.feature`:

  ```gherkin
  Feature: Quadratic programs

    Scenario: A budget is split between two equal assets
      Given a problem in 2 variables with the identity as its matrix
      And both variables between 0 and 1
      And the variables summing to exactly 1
      When it is solved
      Then the answer is certified
      And each variable is 0.5

    Scenario: Bounds that cannot be met are refused
      Given a problem in 2 variables with the identity as its matrix
      And both variables between 0 and 0.25
      And the variables summing to exactly 1
      When it is solved
      Then the outcome is infeasible
  ```
- **Gates:** `make ci`, `make prove`.
- **Done:** `Abacus.Qp`, `Abacus.Qp.Admm`, `Abacus.Qp.Certificate`, `Abacus.Qp.Engine`; `tools/make_qp.py` and its fixtures; qp.feature.

### A11 -- A seeded generator

- **Where:** `src/abacus-random.ads/.adb`.
- **What is wrong:** resampling needs random numbers, and a float
  generator is a float.
- **Why:** the library one is.
- **Fix:** a 64-bit generator in modular arithmetic with an
  explicit state and seed; `Next`, and `Below (N)` without bias.
- **RED first:** `Abacus_Random_Tests.Test_Same_Seed_Same_Stream`.
- **Gates:** `make ci`, `make prove`.
- **Done:** `Abacus.Random` (SplitMix64).

### A12 -- Benchmarks and documents

- **Where:** `bench/`, `README.md`, `docs/`.
- **What is wrong:** nothing measures a kernel.
- **Why:** new.
- **Fix:** `make bench` times dot, rank update, factor, solve and a
  QP at 180 and 3,000 variables, built with `alr build --release`
  (graecus's note: a `make prove` between runs silently changes the
  profile).  The README states the representation, the outcomes and
  what is and is not proved.
- **RED first:** `make bench` has no rule.
- **Gates:** `make ci`.
- **Done:** `bench/`, `make bench`, `bench/results/release.csv`, README.md.

### A13 -- Second-order cone constraints in the solver

- **Where:** `src/abacus-qp.ads` (the rows' kinds),
  `src/abacus-qp-cones.ads/.adb` (new: the cone's geometry),
  `-admm.adb`, `-certificate.ads/.adb`, `-polish.adb`;
  `tools/make_socp.py` and `tests/data/qp_deviation*.txt`.
- **What is wrong:** statera's first consumer (a portfolio-balancing
  tool) seeds every solve with: maximize mean (P w) - lambda times the
  standard deviation of P w, over a table P of T outcomes of n
  columns, w boxed and summing to a budget.  The deviation is a norm,
  ||(P - 1 m') w|| / sqrt (T), so the program is a second-order cone
  program, not a QP, and `Abacus.Qp` cannot pose it.  Squaring it into
  a variance changes the answer (the objective is not monotone in the
  variance for a fixed mean), so it cannot be posed as a QP either.
- **Why:** A10 built the box and the interval rows, which is all a QP
  needs.
- **Fix:** a general row is held either to an interval, as now, or to
  a second-order cone: rows Head .. Last of E x, less their lower
  bounds (the cone's vertex), lie in {(s, u) : ||u|| <= s}.  So
  ||G x + g|| <= h'x + h0 is the head row h' with lower bound -h0 and
  the rows of G with lower bounds -g.  A row's kind is a component of
  `Problem` with a default of `Interval`, so every problem already
  posed means what it meant.
  - The iteration is A10's, unchanged but for the projection: a cone's
    rows are projected together onto the cone, in closed form -- kept
    when ||u|| <= s, zero when ||u|| <= -s, else scaled to the boundary
    ((s + r) / 2, u (s + r) / (2 r)), r = ||u||.  The norm is the
    proved integer root (`Elementary.Root`) of the sum of squares,
    exact at 128 bits; a norm past the values is the iterate leaving
    its range.  The cone's rows share rho_row with the interval rows,
    so the factored matrix is A10's.
  - The certificate grows two residuals: how far E x less the vertex
    lies outside each cone (||u|| - s, at most), held to the primal
    tolerance, and how far -y_row lies outside it (the dual cone: a
    second-order cone is its own dual), held to the dual one; a cone's
    complementarity is |<y_row, E x - vertex>| over its rows.  `Solve`'s
    postcondition is unchanged in form and still proved.
  - The infeasibility certificates generalize: the duals' change is
    projected onto the polar of each cone (-K), whose support over the
    shifted cone is its vertex times the change; a direction recedes in
    a cone when its rows lie in the cone.
  - The polish does not handle cones: an equality-constrained solve
    cannot hold a curved constraint, so a problem with a cone is not
    polished.
  - Oracle: `tools/make_socp.py`, seeded, at the real shape (T = 1,500,
    n = 14, 0 <= w <= 20, sum w = 10, lambda = 75), the epigraph form
    minimize -m'w + lambda t with ||(P - 1 m') w|| / sqrt (T) <= t.
    Clarabel and ECOS at tight tolerance, and an exact solve of the
    optimality conditions on their active set (Newton, to the last
    place) as the answer, the way S0 polished OSQP's.
- **RED first:** `Abacus_Qp_Cones_Tests.Test_Projects_To_Boundary`:
  (0, 3, 4) projects onto the cone at (2.5, 1.5, 2).  Fails to
  compile.
- **Gates:** `make ci`, `make prove`.
- **Done:** `Qp.Row_Kind` and `Problem.Kind`; `Abacus.Qp.Cones`; the
  ADMM's cone projection; `Certificate.Cone_Residual`,
  `Dual_Cone_Residual` and the cone's complementarity in `Certified`;
  the infeasibility and unboundedness certificates over cones; the
  polish declining a cone; `tools/make_socp.py` and the deviation
  fixture; two qp.feature scenarios (see the as-built note).

### A14 -- Scrambled Sobol sequences

- **Where:** `src/abacus-sobol.ads/.adb`, its generated table
  `src/abacus-sobol-directions.ads` from `tools/make_sobol.py`, the
  published direction numbers' first 64 dimensions and their licence
  under `tools/sobol/`.
- **What is wrong:** the same consumer refines its answer by sampling
  around it with a scrambled Sobol sequence (scipy's `qmc.Sobol`, seeded
  per cycle, drawing a power-of-two block), and abacus has only a
  pseudo-random generator.
- **Why:** nothing needed low-discrepancy points before.
- **Fix:** `Abacus.Sobol`: points in [0, 1)**d, d up to 64, each
  coordinate an integer over 2**32 (and as a value on the grid, a shift
  by 8).  The method is scipy's; the stream is not bit-for-bit
  scipy's, which the user chose.
  - Joe and Kuo's direction numbers (`new-joe-kuo-6.21201`, criterion
    D(6)) for the first 64 dimensions, committed as data with their
    licence; nothing is fetched at build time.  The 32 direction numbers
    of a dimension are made from its primitive polynomial and initial
    numbers by the usual recurrence.
  - Gray-code order (Antonov and Saleev): each point is the last with
    one direction number xored in, the one indexed by the lowest zero
    bit of the count.  `Skip` jumps to any index by the Gray code of the
    index.
  - Scrambling as scipy's: a linear matrix scramble (each dimension's
    direction numbers multiplied by a random unit lower-triangular
    binary matrix, so each digit is its own xor some of the digits
    above it) and a digital shift (a random xor), both drawn from
    `Abacus.Random` seeded by the caller.  Both map each elementary
    interval onto one, so a scrambled block keeps the net property.
  - `Next_Block (M)` draws the next 2**M points, refusing by name a
    block that does not start at a multiple of 2**M (whose points would
    not be stratified) or that runs past the 2**32 points there are.
- **RED first:** `Abacus_Sobol_Tests.Test_First_Points`: the first
  eight unscrambled points in three dimensions are 0, 1/2, 3/4, 1/4,
  3/8, 7/8, 5/8, 1/8 (first coordinate) as the published program prints
  them.  Fails to compile.
- **Gates:** `make ci`, `make prove`: absence of run-time errors and
  the range postcondition.
- **Done:** `Abacus.Sobol` (`Unscrambled`, `Scrambled`, `Next`, `Skip`,
  `Next_Block`, `Unit`) and its generated `Abacus.Sobol.Directions`;
  `tools/make_sobol.py`, `tools/sobol/`; `tests/data/sobol.txt`;
  sobol.feature (see the as-built note).

### A15 -- The solver certifies the ratio and mean-CVaR programs

- **Where:** `src/abacus-qp-polish.adb`, `-admm.adb`, `-engine`'s
  settings in `src/abacus-qp.ads`, `src/abacus-qp-scaling.ads/.adb`
  (new), `Arith.Times_Power`; `tools/make_ratio.py` and
  `tests/data/qp_ratio.txt`.  statera's W12b.
- **What is wrong:** statera's maximum-ratio objective, posed
  homogenized (`Statera.Optimize.Sharpe`: y = k w, minimize y'C y with
  the mean row m'y = 1, each group's sum of y / d equal to k, each y_i /
  d_i at most cap k), never certified on the user's real buckets at any
  step size, cap or tolerance tried: `EXHAUSTED` or `DIVERGED`.
  Mean-CVaR's linear program (a level of loss and a shortfall a day)
  refused at some buckets, `EXHAUSTED` at 4,000 iterations.
- **Why (the diagnosis, on every real bucket-cycle of the user's data,
  1,053 of each program, dumped from a scratch copy of statera):**
  1. *The polish could not certify even from the right held set.*  Its
     refinement formed delta r + A'gap on the grid and solved through
     A'A + delta P + delta**2 I; in the null space of the held rows that
     system is delta P, so the grid's rounding came back multiplied by
     1/delta: a dual-residual floor of 2,000-4,000 units against the
     1,100 of 1e-9, moving as 1/delta when delta moved.
  2. *Four corrections were too few, and the gate too strict.*  ADMM's
     iterate holds bounds a dozen corrections from the answer's after a
     hundred iterations, while its dual residual stays far above the
     1e-3 that gated the polish for thousands.
  3. *One step for every row did not suit the program's scale.*  The
     scale k's column holds -cap / budget (10 to 31 on roth) in every
     cap row, about ten times the root of n where the others are near
     one, and the mean row's entries run from a thousandth to one.
     rho_row E'E put the k diagonal past the values (`DIVERGED` at the
     first iteration for 970 of 1,053); OSQP itself, unscaled at rho 1,
     needs 23,000-200,000 iterations on these.
  4. *(mean-CVaR)* the same polish limits, and a tail of
     near-degenerate vertices (below).
- **Fix:**
  - The polish refines 2**12 finer than the grid: the right side formed
    from the exact sums at that scale, the step solved there and brought
    back; the multipliers' change needs no 1/delta.  The coarse step
    stays for a first step whose gaps are past one.
  - `Settings.Corrections` (32) in place of four; the gate
    `Polish_Below` open by default; a polish is not tried again from the
    bounds it last failed from (`Polish.Tried_Before`); when more rows
    are held than variables freed and nothing else is wrong, the held
    inequality with the weakest multiplier is released.
  - Equilibration (Ruiz's method, ten passes at most, in exponents of
    two, stopping at a pass that moves nothing) sets a step per row,
    rho E_r**2 / c, and a proximal term per variable, sigma / (c
    D_j**2): ADMM on the scaled problem is ADMM on the problem as posed
    with those steps, so no entry of the problem is rounded.  A cone's
    rows share a step.  No step is above the setting's: a multiplier
    moves on a lattice of its step in units.  The matrix factored is the
    equilibrated one, c D M D, and the iteration solves M x = B as D (c
    D M D)**-1 c D B.
  - Default steps rho 2**2 (was one) and rho_row 2**3, measured.
- **RED first:** `Abacus_Qp_Polish_Tests.Test_Held_To_The_Grid`: from
  the ratio fixture's exact held set the polish's dual residual is 3,107
  units, the test asks for at most 64.
- **Gates:** `make ci`, `make prove` (and every check at
  `--timeout=1`).
- **Done:** see the Built note below.

### A16 -- A crossover to a vertex for linear programs

- **Where:** `src/abacus-qp-crossover.ads/.adb` (new),
  `src/abacus-qp-held.ads/.adb` (new: the held system taken out of the
  polish), `-polish.adb`, `Settings.Pivots`; `tools/make_ticked.py` and
  `tests/data/qp_ticked.txt`.
- **What is wrong:** after A15, 45 of the user's 1,053 mean-CVaR programs
  were not certified within the default 4,000 iterations, and 3 not by
  40,000.  Each is certified by the polish from the exact held set, and
  ADMM's held set is within one to three bounds of it from the 500th
  iteration, but the vertex is near-degenerate (the outcomes are on a
  grid of ticks, so many tie), ADMM cannot tell the last bounds apart,
  and the polish's corrections, one bound at a time, wander.
- **Why:** the corrections are an active-set method without a ratio
  test: releasing a bound and holding the furthest violation is not a
  pivot, and from a held set with free directions of no curvature it
  moves far from the vertex.
- **Fix:** for a linear program (P zero), the polish hands the iterate
  to a crossover instead of its corrections (unless `Pivots` is zero):
  - the held set read off the iterate is made a basis: a dependent held
    inequality row released, a dependent equality given the held
    variable with its largest entry, a dependent free column held at its
    nearest bound (`Held.Find_Dependence`: A A' then A'A, unregularized,
    factored with a floor), a set square but for one squared;
  - the cost is shifted until every held multiplier has its sign (a row
    through its row of E, a variable one for one), and the dual simplex
    method walks to a feasible vertex (leaving the most violated free
    constraint, entering the held inequality whose multiplier reaches
    zero first, through `Held.Prices`);
  - the shift is taken back and the primal simplex method walks to the
    optimum: Dantzig's rule, Bland's after a step of no length; the ratio
    test along the edge from `Held.Direction`, the entering constraint's
    own range a flip;
  - each vertex is solved through its square system
    (`Held.Solve_Vertex`: A x = b and A'y = -c through A A' with a ridge of
    16 units, refined), and an answer is kept only when certified.
  The design was measured first in a float model on 85 real programs:
  a primal walk with a phase one by infeasibility costs wandered (6 of
  85 at 500 pivots); the shifted dual walk then the primal reached the
  vertex in all 85 (median 4 pivots from 500 ADMM iterations).
- **RED first:** `Abacus_Qp_Crossover_Tests` (a two-variable linear
  program from cold), failing to compile; then
  `Abacus_Qp_Engine_Tests.Test_Ticked`, `EXHAUSTED after 4000
  iterations` with the polish unwired.
- **Gates:** `make ci`, `make prove`, every check at `--timeout=1`.
- **Done:** see the Built note below.

## 4. Features

| file | says |
|---|---|
| `arithmetic.feature` | products and quotients round one way; a result too large is reported, not wrapped |
| `text.feature` | decimals read and write back; malformed text is refused with its reason |
| `ieee.feature` | bit patterns read as their values; not-a-number and infinity are refused by name |
| `elementary.feature` | each function against its definition, at the grid's resolution |
| `stats.feature` | means and covariances on tables small enough to check by hand; order does not matter; a slid window equals a fresh one |
| `cholesky.feature` | factor and solve; a singular matrix is refused and the column named |
| `qp.feature` | small problems with known answers; infeasible, unbounded and non-convex problems each refused by name; a certified answer meets its tolerances; a cone holds a linear objective's answer on its boundary, and the deviation program agrees with two conic solvers; the homogenized ratio program agrees with its exact answer; a tail program whose outcomes tie is crossed over to its vertex |
| `sobol.feature` | the first points as published; a block of 2**k points puts one in each of 2**k equal intervals of every coordinate; a seed gives one stream, two seeds two |

## Revision notes

- **Iteration 1 (draft):** the units, the solver, the spike.
- **Iteration 2 (as a newcomer):** put S0 first with its bars and
  what to try before giving up; added the Do-not list, mostly
  graecus's proof lessons; wrote the representation as code (1.1);
  added the `Solve` contract and the two `qp.feature` scenarios;
  said plainly what is proved and what is checked (1.3).
- **Iteration 3 (against graecus at `cddb356` and its
  `fixed-point-spike` branch, GNAT 15.2.1, gnatprove 15):**
  confirmed the branch exists and that
  `docs/fixed-point-spike.md` reports the 248-fold proof saving,
  the 12.58 ns against 1.17 ns multiply, and that `'Fixed_Value` is
  not allowed in SPARK.  Confirmed by a scratch build that a
  `delta` dot product with a 128-bit accumulator compiles and
  proves at level 2.  Corrected: the draft had the generator in
  statera; resampling belongs beside the statistics.  Corrected:
  the draft cited OpenBLAS as an option for the kernels, which the
  user's choice of an all-SPARK solver rules out.  Not verified,
  and S0 exists to find out: that ADMM converges in fixed point at
  this size, and that the factorization's range proofs go through.
- **S0 (the spike, branch `spike`, 2026-10-06):** go, (b) at Frac
  40; section 2 has the numbers.  What it changes:
  - **1.1:** add `subtype Val is Raw range -2**57 .. 2**57` as the
    bound on every stored value, whatever `Frac`: a product is then at
    most 2^114 and a sum of 4,096 of them fits in 128 bits.  At Frac 40
    a stored value is within about +-131,000, not the +-8.3 million a
    `Raw` holds.
  - **A2:** narrowing goes through one checked store that clears an
    `Ok` and leaves the target as it was, never a silent saturation.
    `Div_Round` takes a `Divisor` subtype (1 .. 2^64) so a count times
    `One` can divide.
  - **A5:** the factorization and the deviations need an integer root
    of a 128-bit value at scale `One * One` (bit by bit, rounded to
    nearest; it proves), not graecus's root over [0, 1].  A deviation
    is taken from the variance raised by fours while it fits.
  - **A8:** standardize, then correlate; the covariance need not exist
    as a matrix.
  - **A9:** pivots as a positive subtype; one rounded division per
    off-diagonal entry; the upper triangle mirrored so the back solve
    reads rows.  3,000 factors in 3.6 s.
  - **A10:** store only the general rows (the box rows are the
    identity); step sizes as powers of two; rho_row small (2^3), not
    OSQP's thousand times rho, because those rows' duals move in
    steps of rho_row units of the grid; tolerances as values (1e-10 /
    1e-9 in correlation space); a `Stalled` outcome for an iterate the
    grid holds still (it never fired on the bucket, whose iterate keeps
    moving at its floor; a two-variable test cycled with period three).  `Solve` as sketched has three `out` parameters, over the
    shape limit of two: the spike passes the iterate as one `in out`
    state record.  Polish is not on the critical path.  At Frac 32 no
    residual rule certifies 1e-6, so `Certified` would never be
    reached there: another reason for 40.
  - **Not tested by S0:** a bucket whose answer holds many assets (the
    oracle's holds three), caps that bind, and the semi-covariance
    twelve of PRO's thirteen optimizers use.
- **Implementation (A1-A12, branch `main`, 2026-10-06):** every item
  built and committed, one cycle or more each, logged in
  `docs/tdd-log.md`.  What changed from the items as written, and why:
  - **Dependencies:** the library depends on sml (the plan says none,
    and also makes the scanner and the solver's loop sml machines).
    `proof/proof.gpr` withs sml only.
  - **1.1 / A2:** `Frac` is a constant, not a generic parameter: S0
    chose one grid.  `Arith.Product_Bound` is 2**126 + 2**110 (a value at
    One * One less a dot of `Max_N` products, the spike's Numerator);
    `Divisor_Bound` is 2**96, up from 2**64, so a power of ten can
    divide.  `Quantities` is a generic over a range (First, Last), not
    "over a name": an instance is already its own type, and a range is
    a bound the prover uses.
  - **Powers of two** are a written-out table (`Arith.Powers_Of_Two`):
    gnatprove would not bound `2**K` for a variable K past about 30,
    in an aggregate or with a typed base.
  - **A3:** a fraction of any length rounds exactly: the whole part
    times One plus (floor (F * 2**41) + 1) / 2, F scaled by a carry from
    its last figure to its first in 64 bits (a limb form needed a
    `10**K` invariant that did not prove).  Text is at most 64
    characters; `Image` writes at most 20 places (13 always read back).
  - **A5:** `Exp` and `Log` work at 2**-60 inside and round once, so
    each is within a unit of the true value (exp relative above one);
    graecus's tables were recomputed at that scale.  `Exp` takes
    arguments up to 11.75.  `Inv_Norm_Cdf` is Wichura's AS 241, its
    tails at 2**-52, within two units of the definition and of scipy.
    The normal CDF keeps Abramowitz-Stegun's 7.5e-8.  graecus's
    polynomial clamp at one was wrong for 26.2.17, whose polynomial
    reaches 1.2533.
  - **A7:** the sort was insertion, O(n**2): 9e6 comparisons at 3,000
    (replaced; see the follow-ups note).
    The quantile's postcondition says "an element" (nearest) or
    "between two neighbours" (linear); "between the least and the
    most" needs transitivity the adjacent-pair sortedness does not
    give the prover.
  - **A8:** the statistics take data of magnitude at most 256
    (`Stats.Datum`): that keeps a variance a value and a window of
    `Max_N` rows inside 128 bits.  Skewness and kurtosis are the means
    of z**3 and z**4.  `Rolling.Remove_Row` refuses a row that cannot
    have been in the window.
  - **A9:** on this grid a singular matrix's last pivot is the root of
    its rounding, about 1e-6, not zero; a pivot floor must sit above
    it.  The dot kernels are `Inline`: across units GNAT inlines only
    what is marked, which the spike hid by compiling them into its
    bench, and the 3,000 factor fell from about 6 s to 4.6 s.
  - **A10:** the units are `Qp` (types), `Qp.Admm` (the iteration and
    its checks), `Qp.Certificate` (residuals, `Certified`, the
    infeasibility certificates) and `Qp.Engine` (the machine and
    `Solve`): `Solve`'s postcondition names `Certificate.Certified`,
    which the parent's spec cannot see.  `Solve (Pr, S, Work, St,
    Result)`: the caller holds the factor's workspace so a 3,000
    problem's need not be on the stack, and the iterate is in out (the
    warm start).  Outcomes: Certified, Infeasible, Unbounded,
    Not_Convex, Stalled, Exhausted, Diverged; a bound at the end of the
    values is no bound.  The machine's states are one per request
    (Preparing, Iterating, Checking, Certifying) and one per outcome;
    there is no Converged or Polished state.  Convexity is a separate
    factorization of P + sigma I, which doubles the factor's cost.  The
    infeasibility certificate projects the duals' change onto the polar
    of the recession cone, as OSQP does.  **Polish was not built** (S0:
    off the critical path).  The tests and fixtures the task added:
    an answer holding 44 variables, 35 at their cap, an at-most budget
    binding beside an exact one (certified, within 1e-6 of OSQP and
    Clarabel); a linear program; infeasible and non-convex problems,
    small and at 120; a warm start that takes fewer iterations.
  - **A10, the open risk (closed by the follow-ups' polish):** the
    tail-mean linear program (the CVaR shape: 131 variables, 101 rows,
    open bounds) is not certified.
    ADMM creeps at residuals near 1e-6 under every step size swept
    (rho 2**-6 .. 2**2, rho_row 2**-2 .. 2**6, sigma 2**-20 .. 2**-6,
    alpha 1 .. 1.75); OSQP does not finish it in 400,000 iterations
    either.  The solve ends Exhausted, never Certified, with the weights
    within 1e-3 of HiGHS's.  statera's CVaR optimizers need more than
    this solver: a polish (an equality-constrained solve on the active
    set, which in fixed point needs a quasi-definite LDL' or a range
    the Schur complement can hold), Ruiz equilibration with adaptive
    rho, or another method for linear programs.  That choice is the
    user's.
  - **A11:** SplitMix64; `Below` rejects by threshold, its redraws
    capped at 128 so the loop's end is a fact.
  - **Features:** wording the registry needed -- "the statistic is"
    (stats), "the matrix of observations" (cholesky), "the root of 2"
    (elementary) -- and qp.feature's first scenario splits a budget
    between "two equal parts", not assets: no trading word in abacus.
    A decimal argument is read to the grid first, so the elementary
    scenarios take arguments the grid holds or state the rounding.

- **Follow-ups (2026-10-06): a fast sort, and the tail program.**
  - **The sort** is a top-down merge sort over the order array,
    O(n log n): each half sorted, then merged through a second order the
    caller passes (`Scratch`, so a long one can come from the heap; the
    library allocates nothing), and a run whose halves already meet in
    order is left as it is.  Proved at level 2 with the same contracts:
    a permutation, sorted by (value, key, place).  The merge carries a
    ghost witness of where each place came from, which is what proves
    the result a permutation.  Spec changes, both for long data: the
    sort takes `Long_Vector` and `Order_Array` over `Place` (1 ..
    2**30), not `Vector` over `Index` -- `Max_N` bounds a 128-bit sum,
    which a sort never forms (a `Vector` converts: `Long_Vector (V)`);
    and `Sort_Order` and `Rank` gain an overload taking `Scratch`.  The
    overloads without it, and `Sort`, keep their copies on the stack.
    The unit ignores its postconditions, invariants and ghost code at
    run time (`Assertion_Policy`): checking whether an order is a
    permutation is a quantifier over every pair, so a build with
    contracts on would make the sort quadratic; the preconditions are
    still checked.  An aggregate that names its target, or an iterated
    one, is built on the stack by GNAT; the order starts from
    `[others => Place'First]` and a loop.
  - **The tail program, the user's three steps in order** (each
    measured; the first that certified is kept):
    1. *Bound it as the caller will* (`tail_bounded`, from
       `tools/make_qp.py`): with w >= 0 summing to the budget B, the
       threshold a lies in [min_s (-B max_j r_sj), max_s (-B min_j
       r_sj)] and each shortfall u_s in [0, -B min_j r_sj - that least
       a].  HiGHS's answer is the open program's within 8.5e-16; the box
       never binds.  ADMM: Exhausted at 40,000, primal 1.5e-6, dual
       3.4e-6, gap 2.8e-7 (the open program: 1.6e-6, 3.8e-6, 2.8e-7); a
       step-size sweep's best, rho_row 1, 5.2e-7.  OSQP: 400,000.
    2. *Ruiz equilibration and adaptive rho*, measured on a float64
       prototype of this solver (scratch, not kept) that reproduced the
       Ada solver's residuals to three figures.  Ruiz is the identity
       here: every row and column of the KKT data already has infinity
       norm one (the budget row's ones, the threshold's column, the
       shortfalls' identity), and so has q.  Adaptive rho_row (OSQP's
       rule, powers of two, refactored on a change of four or more):
       1.1e-6 / 1.4e-6 at 40,000; adapting both rhos, 5.2e-7 / 7.4e-7 at
       best.  Not certified, and OSQP, which has both, is not either; so
       it was not built in Ada.
    3. *Polish* (`Abacus.Qp.Polish`, built): the held bounds read off the
       iterate by OSQP's rule; the free variables solved with the held
       rows as equalities through A'A + delta P + delta**2 I (delta =
       2**-12: the scaled form keeps every entry a value; dividing by
       delta for the multipliers amplifies rounding by 2**12, so they
       are recovered by least squares through A A' instead), refined
       against the exact system; up to four corrections, one constraint
       at a time (releasing every wrong-signed multiplier at once
       overshoots).  Both systems are factored in a leading block
       (`Cholesky.Factor_Leading`), packed over the free variables and
       held rows: a whole-size factorization per attempt made the
       3,000-variable QP 70% slower.  Certifies `tail` and `tail_bounded`
       at 2,100 iterations (90 ms), within 5e-9 of HiGHS; a 180 x 250
       instance (431 variables, 251 rows) at 900 iterations (0.30 s),
       within 7.5e-9, where plain ADMM ends Exhausted at 40,000 after
       11.4 s.  The QPs ADMM certified take the iterations they took.
    - **What statera does:** box the threshold and the shortfalls as in
      step 1 (it costs nothing and keeps the polish's systems in range,
      though the open program certifies too); keep the default
      `Polish_Every` and `Polish_Below`; size `Workspace (N, K)` with
      the rows' count.  The threshold is a level of loss, -r'w, so its
      box is the range of the scenarios' losses, not of their returns.

- **A13 and A14 (2026-10-06), as items:** written for statera's
  reproduction of a portfolio-balancing tool, whose seed solve is a
  second-order cone program and whose refinement samples a scrambled
  Sobol sequence.  Decisions made writing them: a cone is a run of
  general rows with a kind, not a new discriminant, so every problem,
  state and workspace keeps its shape and every caller compiles
  unchanged; a cone's lower bounds are its vertex, so the offset of
  ||G x + g|| <= h'x + h0 needs no new component; the cone rows share
  rho_row (a float prototype of this iteration, at the real shape,
  certified 1e-10 / 1e-9 in about 600 iterations with rho_row 2**3,
  and 2**0 and 2**6 were no better); the oracle's answer is an exact
  solve of the optimality conditions, because Clarabel and ECOS agree
  with each other only to about 1e-6 in the weights on this program
  (its objective is flat along the budget), while the prototype ADMM
  agrees with the exact solve to 1e-10.  The Sobol stream is scipy's
  method with abacus's own seed stream (the user chose that over bit
  equality with scipy).  A user rule arrived with these items: no state
  in a package, everything injected; abacus already kept it, and
  `CLAUDE.md` now states it.

- **A13 and A14, as built (2026-10-06):** each item one TDD cycle or
  more, logged.  What changed from the items as written, and why:
  - **A13, the iteration:** as planned, a cone's rows share rho_row and
    the factored matrix is A10's.  An interval row's arithmetic is
    unchanged (the row update was split into relax, project, settle;
    every QP test takes the iterations it took).
  - **A13, the certificates:** the first certified-looking run of the
    disc ended Unbounded at 10 iterations: the unboundedness check read
    a cone's tail rows as half-open intervals, so a direction out of the
    cone receded.  The duals' change is projected onto each cone's polar
    and a direction must stay in its cones, as the item said; it was
    needed at once, not as a refinement.
  - **A13, the measurement:** the deviation program, certified from cold
    with the default settings: 610 iterations, 72 ms (-O3, best of
    five); residuals 73 units primal, 3 cone, 50 dual, 15 dual cone, 945
    gap; weights within 9.5e-11 of the exact answer, against Clarabel's
    4.1e-6 and ECOS's 1.5e-7.  rho_row from 2**0 to 2**6 took 960 to 540
    iterations, all certified; 2**3 stays the default.
  - **A13, the workspace:** `Workspace (N, K)` holds the polish's K by K
    matrix, 18 MB at K = 1,502, which a cone problem never uses; the
    test support now takes every workspace from the heap.  Not changed
    here (it is the polish's shape); statera allocates it once, or poses
    the cone over the 14 by 14 factor of G'G, ||G w|| = ||L' w||: 16
    rows, 620 iterations, 2.1 ms, within 6.2e-11 (measured, scratch).
  - **A13, how statera poses it:** divide the whole table (decay
    weighting already applied to its rows) by one positive constant --
    the pooled standard deviation of its entries -- which leaves w where
    it was and t scaled by the same constant; dividing column by column
    would change the problem unless the variables change with it.  The
    unscaled table, tens of thousands per entry, puts P w past the
    values (131,072) at w = 20.  Then m, the columns' means, and G = (P
    - 1 m') / sqrt (T) on the grid; x = (w, t); the box 0 .. 20 and t
    open; the budget an interval row; a head row picking t, Row_Lo 0;
    G's rows as its tail, Row_Lo 0; q = (-m, lambda).
  - **A14:** as planned.  The scramble's leading place takes no draw
    (its matrix row is fixed).  Past_End is reached only when every
    point is drawn: 2**32 is a multiple of every block's size, so an
    aligned block that starts before the end fits.  scipy's
    fast_forward walks every index (it did not finish at 3e9), so the
    far-index oracle is the xor of scipy's own direction numbers over
    the Gray code.  The generated table carries Joe and Kuo's copyright
    notice, which their licence requires in a redistribution: the one
    comment in `src/` that names people, deliberately.
  - **Dependency injection:** the library holds no state in a package;
    sobol.feature's region keeps its machine's state in the scenario.
    The seven older feature regions, the suite's registration and the
    benchmark's sink still hold package-level variables: the test
    harness's debt under the new rule, not changed here.

- **A15, as built (2026-10-08):** twelve commits on `main`, each a
  cycle logged in `docs/tdd-log.md`, and this note.  The diagnosis and the measures are
  on the user's real data (scratch only; the fixture is synthetic).
  - **The ratio program** (statera's direct objective), all 1,053
    roth bucket-cycles: before, 0 certified (970 `DIVERGED`, 83
    `EXHAUSTED`); after, 1,053, median 100 iterations, at most 1,500,
    56 s in all (median 21 ms).  With statera's own row step (2**-3):
    before 32, after 1,053, at most 300 iterations, 45 s.
  - **Mean-CVaR**, all 1,053, at the default cap of 4,000: before 893
    (median 1,100 iterations, 953 s in all); after 1,008 (median 600,
    599 s).  The 45 left certify at a larger cap: 28 by 10,000, 34 by
    20,000, 42 by 40,000 (median 6,900); 3 do not by 40,000.  Every one
    of them is certified by the polish from the exact held set read off
    HiGHS's vertex, and ADMM's held set is within one to three
    constraints of it from the 500th iteration; their vertices are
    near-degenerate (a row held by the iterate has a slack of 1.8e-7 at
    the answer, inside ADMM's resolution, or two near-equal columns
    trade places), and correcting one constraint at a time wanders.
    What closes them is a crossover from ADMM's held set to a vertex (a
    simplex phase), or more iterations; that choice is the user's.  Two
    rules were measured and not kept: releasing each held row in turn
    (14 of the 52 then left, at up to eight more solves a polish), and
    holding the free variable whose gradient is largest (none).
  - **Adaptive rho** (OSQP's residual-ratio rule, powers of two),
    measured in a float model of this solver on the same programs: no
    better than a fixed step once the polish corrects, and it thrashed
    (72 refactorizations on one ratio program); not built.  The best
    fixed pair differs by a hundredfold between the ratio programs (any)
    and the linear programs (2**3 or more), which equilibration and the
    polish together make moot at (2**2, 2**3).
  - **Existing answers:** every fixture still certifies, nearer its
    oracle: spread 110 -> 100 iterations, 1.7e-10 -> 1.8e-12 from OSQP's;
    tail and tail_bounded 2,100 -> 1,000, 4.6e-9 -> 1.2e-11 and 5.4e-9 ->
    2.3e-11 from HiGHS's; deviation 610 -> 210, 9.5e-11 -> 2.6e-11 from
    the exact answer (dual residual 175 units of 1,100); infeasible
    refused at 880 iterations, not 1,620; the tail program at 431
    variables 900 -> 800 iterations but 0.32 -> 0.52 s (more polish
    attempts); the bench's QP at 180 60 -> 80 iterations, 3.4 -> 6.0 ms,
    at 3,000 200 -> 100 iterations, 8.7 -> 8.1 s.
  - **The proof:** 2,414 checks, all proved, about 3 min 35 s from
    clean (gnatprove 15, `-j0`, a quiet box); every check at
    `--timeout=1` from clean (2 min 49 s quiet, 5 min 51 s with another
    proof loading the box to 32), none of the changed units' over 0.4
    s.
  - **For statera:** the direct ratio program certifies at the
    defaults or at its own `Row_Shift => -3`; its override is no longer
    needed.  Mean-CVaR wants a larger `Max_Iter` until the crossover is
    decided (40,000 leaves 3 of 1,053).

- **A16, as built (2026-10-08):** five commits on `main`, each a cycle
  logged in `docs/tdd-log.md`, and this note.
  - **Mean-CVaR, all 1,053 roth bucket-cycles** (scratch, release build,
    a quiet box): before (79737ac), 1,008 certified, median 600
    iterations, 640 s in all (median 0.38 s, at most 9.4 s); after,
    **1,053**, median 100 iterations, at most 1,300, 143 s in all (median
    0.11 s, at most 2.1 s).  The certifying walk takes 15 pivots at the
    median, 114 at most; a solve crosses over once at the median, 12
    times at most (each from a new held set), 19 pivots in all at the
    median, 433 at most.  Every one of the 45 that refused, and the 3
    that refused at 40,000, certifies.
  - **The ratio program (max Sharpe), all 1,053:** unchanged -- a
    quadratic term is polished as before; the same iterations to the
    program, the same answers bit for bit on those compared.
  - **Fixtures:** tail and tail_bounded 1,000 -> 100 iterations (73 ->
    10 ms), their answers within 2.9e-11 and 1.5e-11 of HiGHS's (were
    1.2e-11 and 2.3e-11), moved by 4.0e-11 at most; ticked: certified at
    100 (the corrections at 25,200); spread, deviation, ratio and
    infeasible: unchanged.  The synthetic ticked family (80 seeds):
    80 certified at 200 iterations at most, where 3 were not.
  - **The proof:** 2,854 checks, all proved, 4 min 33 s from clean
    (gnatprove 15, `-j0`, the box loaded to about 10 by another proof);
    every check at `--timeout=1` from clean (3 min 36 s, load near 19),
    none of the crossover's over 0.3 s and none of the units this item
    changed over 0.4 s.
  - **What was not done, and why:** an exact-rational pivot (no integer
    beyond 128 bits); the corrections are kept for a program with a
    quadratic term, whose answer need not be a vertex.
- **A16, a regression and its fix (2026-10-08):** statera's repin of
  b382aaa found a synthetic mean-CVaR program (beta 0.9, weight 2; two
  parts of one column each, so the budgets pin both and the vertex is
  degenerate) that certified on 79737ac and ran to the cap after: every
  crossover gave up before its first pivot -- the basis found a budget
  row, its column free, dependent on inequality rows held before it, and
  could neither release it nor free a variable in it -- and the polish
  then made no corrections.  Two fixes, each a cycle: a failed crossover
  leaves the corrections to the polish, so it can only add to what the
  polish certifies; and the dependence check packs the held rows
  equalities first, so a dependence is found on an inequality, which
  can be released.  The program is the fixture `qp_pinned.txt` (from
  statera's synthetic view; HiGHS's vertex solved exactly as the
  oracle).  All 1,053 roth mean-CVaR programs still certify, median 100
  iterations, at most 1,300, 133,500 in all (140,600 before the second
  fix); the ratio programs, the fixtures and the synthetic ticked family
  as before.  `Abacus.Qp.Picks` took the picks out of `Held`, whose body
  had passed a thousand lines.
