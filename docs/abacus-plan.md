# abacus plan

**Status (2026-10-06):** planned, nothing built.  Three iterations
done (see Revision notes).

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

### 1.3 What is proved

Absence of run-time errors everywhere.  Functional contracts where
they are cheap and worth having: a sort returns a sorted permutation;
a quantile is an element of its input; a projection lies in its
box; `Certified` means what its expression function says.  The
solver's algorithm is not proved to converge; its answer is checked,
and the check is proved.

## 2. S0's verdict

*To be filled in by S0.*

| criterion | bar | measured |
|---|---|---|
| proof | every check of the spike units proves at level 2, whole run under 10 minutes | |
| accuracy | weights for the test bucket within 1e-6 of the oracle's | |
| speed, one bucket | 180 assets, 250 days: estimate, factor and solve under 100 ms | |
| speed, large | factor a 3,000 x 3,000 matrix under 60 s | |

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

### A11 -- A seeded generator

- **Where:** `src/abacus-random.ads/.adb`.
- **What is wrong:** resampling needs random numbers, and a float
  generator is a float.
- **Why:** the library one is.
- **Fix:** a 64-bit generator in modular arithmetic with an
  explicit state and seed; `Next`, and `Below (N)` without bias.
- **RED first:** `Abacus_Random_Tests.Test_Same_Seed_Same_Stream`.
- **Gates:** `make ci`, `make prove`.

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

## 4. Features

| file | says |
|---|---|
| `arithmetic.feature` | products and quotients round one way; a result too large is reported, not wrapped |
| `text.feature` | decimals read and write back; malformed text is refused with its reason |
| `ieee.feature` | bit patterns read as their values; not-a-number and infinity are refused by name |
| `elementary.feature` | each function against its definition, at the grid's resolution |
| `stats.feature` | means and covariances on tables small enough to check by hand; order does not matter; a slid window equals a fresh one |
| `cholesky.feature` | factor and solve; a singular matrix is refused and the column named |
| `qp.feature` | small problems with known answers; infeasible, unbounded and non-convex problems each refused by name; a certified answer meets its tolerances |

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
