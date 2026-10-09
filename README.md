# abacus

Fixed-point numerics for Ada 2022, proved in SPARK: arithmetic on
scaled integers, decimal text and IEEE-754 bit patterns, elementary
functions, vectors, sorting and quantiles, statistics, dense linear
algebra, a solver for quadratic and second-order cone programs with a
certificate, a seeded generator, and scrambled Sobol sequences.  No floating-point type appears anywhere in it.

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
| `Abacus.Arith` | the rounding, products, quotients, saturation, the checked store, powers of two, a wide value times a power of two |
| `Abacus.Quantities` | a generic giving a consumer one private type per kind of quantity, held to a range |
| `Abacus.Text` | decimal text to a value (an sml scanner) and back |
| `Abacus.Ieee` | binary64 and binary32 bit patterns to a value |
| `Abacus.Elementary` | integer root, square root, exp, log, the normal CDF and its inverse |
| `Abacus.Vectors` | dot, sum, infinity norm, axpy, scale |
| `Abacus.Sorting` | a stable merge sort with a caller's key over as many as 2**30 elements (`Long_Vector`), ranks, quantiles (nearest, linear) |
| `Abacus.Stats` | means, weighted mean, variance, covariance, correlation, skewness, kurtosis, z-scores and Z Z' |
| `Abacus.Stats.Rolling` | a window of exact sums that slides |
| `Abacus.Matrices` | the dot kernels, products, Gram matrices |
| `Abacus.Cholesky` | factor (refusing by column), the two triangular solves, either over a leading block alone, least squares |
| `Abacus.Qp` | the problem, its settings, tolerances, state and outcomes |
| `Abacus.Qp.Admm` | the iteration and the checks between iterations |
| `Abacus.Qp.Certificate` | the residuals, `Certified`, and the infeasibility certificates |
| `Abacus.Qp.Cones` | the second-order cone over a run of a vector: its norm (the proved integer root), the projection onto it and its polar, how far outside |
| `Abacus.Qp.Scaling` | equilibration, as a step for each row and variable and the scales of the matrix the iteration factors |
| `Abacus.Qp.Held` | the problem with a set of bounds held: read off an iterate, solved for a cost given, its square system both ways, its dependences, a vertex |
| `Abacus.Qp.Polish` | the polish: the held system solved and corrected one constraint at a time |
| `Abacus.Qp.Crossover` | a linear program walked by pivots from the held set to a certified vertex |
| `Abacus.Qp.Picks` | the constraints a held set picks to change |
| `Abacus.Qp.Engine` | the solver's loop, an sml machine, and `Solve` |
| `Abacus.Random` | SplitMix64 with an explicit state, and `Below` without bias |
| `Abacus.Sobol` | Sobol sequences in up to 64 dimensions from Joe and Kuo's direction numbers, scrambled from a seed, in Gray-code order, with `Skip` and blocks of 2**M points |

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
- `Sobol.Next` and `Sobol.Skip`: `Ok`, cleared once the 2**32 points
  are drawn; `Sobol.Block_Result`: `Filled`, `Misaligned` (a block that
  does not start at a multiple of its size), `Past_End`.
- `Qp.Outcome`: `Certified`, `Infeasible`, `Unbounded`, `Not_Convex`,
  `Stalled`, `Exhausted`, `Diverged`.

## The QP solver

Minimize (1/2) x'P x + q'x subject to lo <= x <= hi and row_lo <= E x
<= row_hi.  A bound at the end of the values (`Qp.No_Lower`,
`Qp.No_Upper`) is no bound.  The method is ADMM in the
operator-splitting form, as OSQP: P + diag (sigma + rho) + E'R E is
factored once and each iteration solves with it, projects, and updates
the duals; every step size is a power of two.  The steps are
equilibrated (`Abacus.Qp.Scaling`): Ruiz's method, in exponents of two,
scales the optimality system's columns and rows to a largest entry
near one, and ADMM on that scaled problem is ADMM on the problem as
posed with a step for each row (rho times its scale squared over the
cost's) and a proximal term for each variable -- so the problem is
never scaled and none of its entries is rounded.  A cone's rows share
one step, and no step is above the setting's (2**2 on the box rows,
2**3 on the general rows): a multiplier moves on a lattice of its step
in units of the grid.  The matrix factored is the equilibrated one, c D
M D, whose entries are near one whatever the problem's scale.  The
caller holds the
`Workspace` (N, K) -- the factor, and the polish's matrices -- so a
large problem's need not live on the stack, and passes the iterate in
and out, so a warm start is the last answer.

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

**The polish.**  ADMM settles which bounds a linear program's answer
holds long before its residuals meet these tolerances, and then creeps:
the tail-mean program in `tests/data/qp_tail.txt` (131 variables, 101
rows) sits near 1e-6 after 40,000 iterations under every step size, and
OSQP does not finish it in 400,000.  So every `Polish_Every` (100)
iterations, whatever the residuals (`Polish_Below` is open by default),
the solver reads the held bounds off the iterate (OSQP's rule), fixes
the held variables and solves for the free ones with the held rows as
equalities: A'A + delta P + delta**2 I, delta = 2**-12, over the free
variables and refined against the exact system 2**12 times finer than
the grid -- a step formed on the grid itself comes back from the null
space of the held rows with its rounding multiplied by 1 / delta --
then the rows' multipliers by least squares through A A', both by the
Cholesky factorization of a leading block, so an attempt costs the
size of the free set, not of the problem.  An answer that is not
certified is corrected one constraint at a time -- a wrong-signed
multiplier released, a violated bound held, or, when more rows are held
than variables freed, the weakest held inequality released -- up to
`Corrections` (32) times; a polish is not tried again from the bounds
it last failed from.  An answer is kept only when its certificate
holds; otherwise the iteration goes on from where it was.
`Polish_Every => 0` turns it off, and the tail program then ends
`Exhausted`, never `Certified`.

**The crossover.**  A linear program's answer is a vertex, and at a
near-degenerate one -- many outcomes tying -- ADMM's held set comes
within a few bounds of the answer's early and then cannot tell them
apart, while corrections one bound at a time wander.  So a linear
program is not corrected but crossed over (`Abacus.Qp.Crossover`):
the held set read off the iterate is made a basis (dependent rows
released, dependent columns held, the set squared, through `A A'` and
`A'A` factored with a floor); the cost is shifted until every held
multiplier has its sign, and the dual simplex method walks to a
feasible vertex; the shift is taken back and the primal simplex method
-- Dantzig's rule, Bland's after a step of no length -- walks to the
optimal one.  Each vertex is solved through its square system and the
answer kept only when its certificate holds; when a crossover fails, the
polish corrects as it would have.  `Pivots` (200) caps a walk; zero
leaves the corrections alone.  The tail program is
certified at 100 iterations (10 ms), within 2.9e-11 of HiGHS; the
ticked tail program (`tests/data/qp_ticked.txt`, 318 variables, its
outcomes on ticks, from `tools/make_ticked.py`) at 100, where the
corrections took 25,200.

**The ratio program.**  A ratio m'w / sqrt (w'C w) over w >= 0 in parts
summing to budgets, each w_i capped, posed homogenized -- y = k w,
minimize y'C y with m'y = 1, each part's sum of y equal to k and each
y_i at most cap k -- puts a column ten times the root of n where the
others are near one (k's, in every cap row) beside a row of entries
from a thousandth to one (the mean's).  One step for every row suits
neither: on 1,053 such programs from real data abacus certified none,
the factored matrix past the values for most.  Equilibrated, with the
polish above, it certifies all 1,053, in 100 iterations for most and
1,500 at most (`tests/data/qp_ratio.txt`, 151 variables and 153 rows,
synthetic, from `tools/make_ratio.py`: 100 iterations, 15 ms, within
2e-12 of the exact answer).  The same data's tail-mean linear programs
(a threshold and a shortfall per scenario, 250 to 800 variables) are
all certified by the crossover, 1,053 of 1,053, in 100 iterations for
most and 1,300 at most (median 0.11 s; without it 1,008 within the
default cap).

**Second-order cones.**  A run of general rows may lie in a cone
instead of an interval: `Problem.Kind` marks a row `Cone_Head` (it
begins a cone) or `Cone_Tail` (it continues the one above), and the
cone's rows of E x, less their `Row_Lo` -- the cone's vertex -- lie in
{(s, u) : ||u|| <= s}, s the head's.  So ||G x + g|| <= h'x + h0 is a
head row h' with `Row_Lo` -h0 and the rows of G with `Row_Lo` -g;
`Row_Hi` is not read.  Every row defaults to `Interval`, so a problem
posed without kinds is a QP as before.  The iteration projects a cone's
rows onto it in closed form (kept inside, zero inside its polar, else
scaled to the boundary), the norm the proved integer root of an exact
sum of squares.  A certified answer is also held to how far its rows lie
outside their cones (the primal tolerance) and its multipliers outside
the cones' polars (the dual one), and to each cone's complementarity.
The infeasibility and unboundedness certificates project the duals'
change onto each cone's polar and ask a receding direction to stay in
its cones.  The polish does not handle cones: a problem with one is not
polished, and its answer is ADMM's.

The deviation program -- maximize the mean of P w less 75 times its
standard deviation, ||(P - 1 m') w|| / sqrt (T), for 1,500 outcomes of
14 columns, 0 <= w <= 20, sum w = 10, posed as minimize -m'w + 75 t
with the deviation at most t, a cone of 1,501 rows
(`tests/data/qp_deviation.txt`, from `tools/make_socp.py`) -- is certified from
cold with the default settings at 210 iterations in 31 ms, its weights
within 2.6e-11 of the exact answer (Clarabel's are 4.1e-6 from it,
ECOS's 1.5e-7).  A caller brings such data inside the values by
dividing the whole table by one positive constant, which leaves w where
it was.  Its workspace is 18 MB, mostly the polish's K by K matrix, so
it belongs on the heap.  The same cone over the 14 by 14 factor of G'G
(||G w|| = ||L' w||) is 16 rows: 620 iterations in 2.1 ms, as close
(measured before equilibration).

## Scrambled Sobol sequences

`Abacus.Sobol` gives points in [0, 1)**d, d up to 64, each coordinate an
integer over 2**32 (`Unit` puts one on the grid).  The direction numbers
are Joe and Kuo's, criterion D(6), for the first 64 dimensions, kept
with their licence under `tools/sobol/` and made into
`src/abacus-sobol-directions.ads` by `tools/make_sobol.py`; nothing is
fetched to build.  Points come in Gray-code order; `Skip` reaches any
index at once.  `Scrambled (D, Seed)` is scipy's method -- a random
unit lower-triangular binary matrix applied to each dimension's
direction numbers and a random digital shift -- drawn from
`Abacus.Random`, so the stream is abacus's, not scipy's.  `Next_Block
(M)` draws the next 2**M points, as scipy's `random_base2` does; a block
that starts at a multiple of its size puts one point in each of 2**M
equal intervals of every coordinate.  The first 64 points in 64
dimensions and points at far indices up to the last equal scipy's
unscrambled ones; a scrambled block's L2-star discrepancy equals
scipy's for the same points and lies within what scipy's own scrambled
points reach over 64 seeds.  A sequence is an object the caller holds.

## What is proved and what is checked

`make prove` runs gnatprove at level 2 with `--checks-as-errors=on` over
every unit in `src/`: no `pragma Assume`, no `SPARK_Mode Off`; 2,854
checks, all proved, in about 4 1/2 min from a clean object directory
(gnatprove 15, `-j0`, 12 cores, the box shared).  Every check also proves with
`--timeout=1`, a fifth of level 2's budget, none of the solver's over
0.4 s -- and still did with another proof sharing the cores (load 32) --
so a slower runner has room.  Proved:

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
  bound; a Sobol coordinate as a value lies in [0, 1), `Next` and `Skip`
  advance the count by what they drew or refuse and leave it, a filled
  block advances it by its size and a refused one leaves the sequence; `Qp.Polish.Run` passes only an answer `Certificate.Certified`
  holds for, and leaves the iterate as it was otherwise; and
  `Qp.Engine.Solve` returns `Certified` only when
  `Certificate.Certified` holds for the answer it returns.

Checked, not proved, by the AUnit suite and the features:

- that an approximation meets its stated error: exp and log within a
  unit of the true value (exp relative above one), the normal CDF within
  Abramowitz and Stegun's 7.5e-8, its inverse within two units of AS 241 and
  of scipy's `ndtri` (`tests/data/elementary.txt`, from
  `tools/make_elementary.py`);
- that the solver converges: the algorithm is not proved to reach an
  answer, nor the polish to find the bounds an answer holds, nor the
  equilibration to balance anything, only that an answer it calls
  certified is one.  The fixtures from `tools/make_qp.py` hold it to
  OSQP, Clarabel and HiGHS within 1e-6, and `tools/make_socp.py`'s and
  `tools/make_ratio.py`'s to the exact solution of the optimality
  conditions;
- that the Sobol points are the published ones and that a scrambled
  block is stratified and as evenly spread as scipy's
  (`tests/data/sobol.txt`, from `tools/make_sobol.py`).

## Using it

```
make build      # the library
make test       # the AUnit suite, -O0 and -O3
make features   # the Gherkin features, both modes
make prove      # SPARK proof
make bench      # the benchmark, at -O3
make ci         # every gate
```

What abacus does is stated as Gherkin features in
[tests/features](tests/features), and published as living documentation
at <https://ldm5180.github.io/abacus/> from every push to main.

The library depends on sml alone (the scanner and the solver's loop
are sml machines); AUnit and fabula are for the tests.

## Benchmark

`make bench`, on one core, release profile (language checks on,
contracts off), the second of two runs (`bench/results/release.csv`):

| | 180 | 3,000 |
|---|---|---|
| dot product | 0.24 us | 2.6 us |
| rank update Z Z', 250 observations | 2.0 ms | 0.58 s |
| Cholesky factor | 0.65 ms | 3.4 s |
| the two triangular solves | 0.02 ms | 7.9 ms |
| QP in correlation space, certified | 6.0 ms (80 iterations) | 8.1 s (100 iterations) |

| | 1,000,000 | 4,000,000 |
|---|---|---|
| sort order, values among 4,096, keys among 2**20, scratch from the heap | 0.17 s | 0.91 s |

The QP at 3,000 pays two factorizations, one of them the convexity
check; at 180, equilibration and the polish's attempts are most of it.  Timings on one box move by up to 30% between runs at the small
size.

## License

MIT.
