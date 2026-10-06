# abacus

Fixed-point numerics for Ada 2022, proved in SPARK: arithmetic on
scaled integers, decimal text and IEEE-754 bit patterns, elementary
functions, vectors, sorting and quantiles, statistics, dense linear
algebra, a quadratic-program solver with a certificate, and a seeded
generator.  No floating-point type appears anywhere in it.

The name is the counting board: arithmetic done with whole beads.

## The representation

A value is a 64-bit integer counting units of 2**-40 (`Abacus.Frac`):
one is 2**40 units, and the resolution is about 9.1e-13.  Every stored
value is bounded at 2**57 units (`Abacus.Val`, about +-131,072), so the
product of two fits in 114 bits and a sum of `Max_N` (4,096) products
in 127.

A product is formed in a 128-bit integer (`Abacus.Wide`) and rounded
once, to nearest with ties away from zero (`Abacus.Arith.Div_Round`,
the one rounding the crate takes).  A dot product, a sum or a sum of
squares is accumulated exactly at 128 bits and rounded once at the end,
so the order of the terms -- and how the work is split -- cannot change
a result.  A result that might not fit is either proved to fit from its
operands' subtypes (`Mul`, `Div`), saturated inside the 128-bit
intermediate and reported (`Mul_Sat`, `Div_Sat`), or narrowed through
the one checked store (`Arith.Store`), which clears an `Ok` and leaves
the target as it was.

This is the representation the S0 spike chose (`docs/abacus-plan.md`,
section 2; `spike/` is its record): Ada `delta` types were measured and
declined, because SPARK cannot bring a raw integer into one and the
per-element rescale ADMM needs is eleven times slower.

## The units

| unit | holds |
|---|---|
| `Abacus` | `Raw`, `Wide`, `Val`, the scale, `Vector`, `Matrix` |
| `Abacus.Arith` | the rounding, products, quotients, saturation, the checked store, powers of two |
| `Abacus.Quantities` | a generic giving a consumer one private type per kind of quantity, held to a range |
| `Abacus.Text` | decimal text to a value (an sml scanner) and back |
| `Abacus.Ieee` | binary64 and binary32 bit patterns to a value |
| `Abacus.Elementary` | integer root, square root, exp, log, the normal CDF and its inverse |
| `Abacus.Vectors` | dot, sum, infinity norm, axpy, scale |
| `Abacus.Sorting` | a stable sort with a caller's key, ranks, quantiles (nearest, linear) |
| `Abacus.Stats` | means, weighted mean, variance, covariance, correlation, skewness, kurtosis, z-scores and Z Z' |
| `Abacus.Stats.Rolling` | a window of exact sums that slides |
| `Abacus.Matrices` | the dot kernels, products, Gram matrices |
| `Abacus.Cholesky` | factor (refusing by column), the two triangular solves, least squares |
| `Abacus.Qp` | the problem, its settings, tolerances, state and outcomes |
| `Abacus.Qp.Admm` | the iteration and the checks between iterations |
| `Abacus.Qp.Certificate` | the residuals, `Certified`, and the infeasibility certificates |
| `Abacus.Qp.Engine` | the solver's loop, an sml machine, and `Solve` |
| `Abacus.Random` | SplitMix64 with an explicit state, and `Below` without bias |

## Outcomes, never exceptions

Nothing in the library raises.  Every operation that can fail returns
what happened:

- `Arith.Status`: `Ok`, `Saturated` (held at the largest value of its
  sign), `Undefined` (a quotient by zero).
- `Text.Read`: `Ok` or an `Error_Kind` -- `Empty`, `Unexpected` (with
  the character's position), `Incomplete`, `Too_Long`, `Out_Of_Range`.
- `Ieee.Outcome`: `Ok`, `Not_A_Number`, `Infinite`, `Out_Of_Range`.
- `Stats.Estimate_Result` and `Correlation`'s status: `Degenerate` or
  `Undefined` for a series with no spread, named by its index.
- `Cholesky.Factor_Outcome`: `Factored`, or `Not_Positive_Definite` or
  `Out_Of_Range` with the column it failed at; the pivot floor is the
  caller's.
- `Qp.Outcome`: `Certified`, `Infeasible`, `Unbounded`, `Not_Convex`,
  `Stalled`, `Exhausted`, `Diverged`.

## The QP solver

Minimize (1/2) x'P x + q'x subject to lo <= x <= hi and row_lo <= E x
<= row_hi.  A bound at the end of the values (`Qp.No_Lower`,
`Qp.No_Upper`) is no bound.  The method is ADMM in the
operator-splitting form, as OSQP: P + sigma I + rho I + rho_row E'E is
factored once and each iteration solves with it, projects, and updates
the duals; every step size is a power of two.  The caller holds the
factor's `Workspace`, so a large problem's need not live on the stack,
and passes the iterate in and out, so a warm start is the last answer.

A certified answer is held to `Qp.Certificate.Certified`: its primal
residual (how far x and E x lie outside their bounds), its dual
residual (the size of P x + q + y + E'y_row) and its complementarity
(each multiplier times the slack of its bound) computed at 128 bits,
each within its tolerance.  The defaults (1e-10 primal, 1e-9 dual and
gap) are S0's, for a problem in correlation space: P with a unit
diagonal and entries in -1 .. 1.  Infeasible and unbounded problems are
refused by OSQP's two certificates, read from the change between
checks; a P that is not positive semidefinite by a refused
factorization of P + sigma I.

What it does not do well: a linear program that ADMM converges on
slowly.  The tail-mean program in `tests/data/qp_tail.txt` (131 variables,
101 rows) creeps at residuals near 1e-6 and is not certified in 40,000
iterations -- OSQP does not finish it in 400,000 -- so it ends
`Exhausted`, never `Certified`.  There is no polish step.

## What is proved and what is checked

`make prove` runs gnatprove at level 2 with `--checks-as-errors=on` over
every unit in `src/`: no `pragma Assume`, no `SPARK_Mode Off`; 1,411
checks, all proved, in 75 s from a clean object directory (gnatprove 15,
`-j0`).  Proved:

- absence of run-time errors everywhere: no overflow, no range or index
  error, no division by zero, every loop terminating;
- the contracts on the operations, among them: `Div_Round`'s sign and
  magnitude; `Store` leaves its target when the value does not fit; a
  parse's `Ok` and its error agree; the sort returns a permutation of
  its input in the order value, key, place (so it is stable) and the
  sorted values are the old ones through that permutation; a nearest
  quantile is an element of its input and a linear one lies between two
  neighbours; `Norm_Inf` bounds every entry; a rolling window keeps its
  sums within the bounds of its row count through every add and remove;
  `Factor` names a column exactly when it refuses; `Below` is under its
  bound; and `Qp.Engine.Solve` returns `Certified` only when
  `Certificate.Certified` holds for the answer it returns.

Checked, not proved, by the AUnit suite and the features:

- that an approximation meets its stated error: exp and log within a
  unit of the true value (exp relative above one), the normal CDF within
  Abramowitz and Stegun's 7.5e-8, its inverse within two units of AS 241 and
  of scipy's `ndtri` (`tests/data/elementary.txt`, from
  `tools/make_elementary.py`);
- that the solver converges: the algorithm is not proved to reach an
  answer, only that an answer it calls certified is one.  The fixtures
  from `tools/make_qp.py` hold it to OSQP, Clarabel and HiGHS within
  1e-6.

## Using it

```
make build      # the library
make test       # the AUnit suite, -O0 and -O3
make features   # the Gherkin features, both modes
make prove      # SPARK proof
make bench      # the benchmark, at -O3
make ci         # every gate
```

The library depends on sml alone (the scanner and the solver's loop
are sml machines); AUnit and fabula are for the tests.

## Benchmark

`make bench`, on one core, release profile (language checks on,
contracts off), the second of two runs (`bench/results/release.csv`):

| | 180 | 3,000 |
|---|---|---|
| dot product | 0.20 us | 3.3 us |
| rank update Z Z', 250 observations | 2.9 ms | 0.73 s |
| Cholesky factor | 0.95 ms | 4.6 s |
| the two triangular solves | 0.03 ms | 9.8 ms |
| QP in correlation space, certified | 5.0 ms (60 iterations) | 10.5 s (200 iterations) |

The QP at 3,000 pays two factorizations, one of them the convexity
check.  Timings on one box move by up to 30% between runs at the small
size.

## License

MIT.
