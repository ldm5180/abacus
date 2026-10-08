# abacus

Fixed-point numerics for Ada 2022, proved in SPARK: arithmetic on
scaled integers, decimal text and IEEE-754 bit patterns, elementary
functions, vectors, sorting and quantiles, statistics, dense linear
algebra, a QP solver, a seeded generator.  No floating-point type
appears anywhere in it.  The plan is `docs/abacus-plan.md`; its
section 2 holds the spike's verdict, and `spike/` is the record of that
spike (not built by the crate).

A value is a 64-bit integer counting units of 2**-40 (`Abacus.Frac`).
A product is formed in a 128-bit integer and rounded once; a sum of
products is accumulated at 128 bits and rounded once at the end.  Every
stored value is bounded at 2**57 units (`Abacus.Val`), so a product
fits in 114 bits and a sum of `Max_N` of them in 127.

Nothing in abacus knows about trading: no trading word in a name or a
comment.

## Commands

- `make build`    — build the library (`alr build`)
- `make test`     — AUnit suite in BOTH modes (release -O3, debug -O0),
  offline
- `make features` — the Gherkin features under `tests/features/` in
  both modes, on fabula, printing the report as it goes (in colour on a
  terminal); checks the summary line, since fabula exits 0 for a
  missing path.  `alr test` runs them too
- `make features-report` — the living documentation: the features with
  `--report-json`, rendered by multiple-cucumber-html-reporter
  (`tools/features-report`, node) into `obj/features-report/html`
- `make prove`    — SPARK proof, `--level=2 --checks-as-errors=on`; must
  exit 0.  Stopped after 30 minutes
- `make format`   — `gnatformat --check` over the committed Ada sources
  (it sees only git-tracked files: stage a new file first)
- `make validation` — `alr build --validation`: 79 columns, `and then`
  in a contract, warnings as errors
- `make no-float` — no floating-point type in any Ada source
- `make shape`    — the shape lint (`tools/shape_check.py`)
- `make bench`    — the benchmark at 180 and 3,000 (`alr build --release`
  first; run it twice and keep the second).  `make bench-build`
  compiles it, and `make ci` runs that so the bench always builds
- `make ci`       — every gate above, cheapest first

## Layout

- `src/` — the library, flat: every unit carries `SPARK_Mode`, does
  zero IO, allocates nothing, raises nothing, and withs only other
  Abacus units and sml.
- `tests/` — AUnit suite (`test_abacus.gpr`, driver `test_runner.adb`)
  and the features: `tests/features/*.feature` run by
  `abacus_features.ads` (Fabula.Main over `Abacus_Steps`).  The steps
  are sml machines run by `Abacus_Steps.Flows`, one child per feature,
  each offered every step as a region of the registry; a step none
  takes fails, naming every region's state.  Every condition is a
  guard, and a guarded row is followed by an unguarded fallback row
  whose action fails the step with the reason.
- `proof/` — gnatprove harness (`proof.gpr`; sources `../src` directly
  and withs only sml).  `proof/src/abacus_proof.ads` withs every unit
  and instantiates every generic: keep it complete.
- `tools/` — `shape_check.py`, the features report, and the seeded
  fixture scripts (`make_elementary.py`, `make_qp.py`, `make_socp.py`,
  `make_ratio.py`, writing `tests/data/`; they need numpy, scipy, osqp,
  clarabel and ecos), and `make_sobol.py`, which writes the Sobol direction table
  `src/abacus-sobol-directions.ads` from the published numbers kept in
  `tools/sobol/` (with their licence) and the Sobol fixture.  Python
  only ever writes fixtures and that table; it never runs at build or
  test time.
- `bench/` — the benchmark (`bench.gpr`, not built by `alr build`) and
  `bench/results/`, the numbers last kept.
- `spike/` — S0's record.  Not built, not held to the gates.
- `docs/tdd-log.md` — git-ignored TDD audit log.

## SPARK

- Every unit in `src/` carries `SPARK_Mode`.  After any change,
  `make prove` must exit 0.  No `pragma Assume`, no `SPARK_Mode Off`.
- Outcomes and result records, never exceptions.
- Bound the operands of a nonlinear operation by subtypes; never state
  a bound on its result and hope.  Never write `abs` on an
  unconstrained integer: state ranges.
- Narrowing goes through one checked store (`Abacus.Arith.Store`) that
  clears an `Ok` and leaves the target as it was.

## Dependency injection

- No package-level variable, set-once cell or singleton.  Everything a
  subprogram needs arrives as a parameter, a generic formal, or a field
  of an object it was handed: a generator's state, a solver's iterate
  and workspace, a sequence's scramble are objects the caller holds and
  passes.  Constants are fine.

## TDD protocol (strict)

- Red/green/refactor, every cycle: failing test first (RED = compile
  error or failed assertion), then the minimal code (GREEN), then a
  REFACTOR pass that looks outward from the diff (duplication, a helper
  that now has two callers, names, shape, stale comments).  "Nothing to
  refactor" is a finding, stated with its reason.
- Log every cycle in `docs/tdd-log.md` (git-ignored, newest on top):
  date, change, exact RED output, GREEN pass counts, refactor result.
- One `<unit>_tests.ads/.adb` pair per library unit under `tests/src/`,
  registered in `abacus_suite.adb`.
- Tests are layers.  A unit test covers its function completely and
  holds the mechanism.  A feature states a behavior in a reader's words
  and checks only what a caller sees.
- Never test an approximation against "the true value": test it
  against its own definition, and against an oracle fixture within the
  grid's resolution.

## Shape (enforced by `make shape`)

| rule | limit |
|---|---|
| statement lines in a subprogram body | 40 |
| total lines of a subprogram | 60 |
| block nesting depth | 3 |
| nested subprogram bodies | none, except expression functions of at most 3 lines |
| parameters | 5 |
| `out` parameters | 2; more means a record (an `in out` subject is not counted) |
| adjacent `Boolean` parameters | never |
| lines in a body file | 1,000 |
| bare numeric literal >= 100 outside a `constant` | never |

Comments: the first sentence of a declaration's comment says what it
is; at most 8 lines; no project codes, people, or dates.  Event
literals take an `E_` prefix.

## Style

- Formatting is `gnatformat`-enforced; wrap hand-aligned tables in
  `--!format off` / `--!format on`.
- Follow the Alire validation-profile switch set; fix warnings, never
  suppress them without a comment saying why.

## Commit style

- gitmoji `:code:` shortcode prefix + capitalized, imperative subject,
  no trailing period; the body says why.
- Never put test / prove / format result counts in commit messages.
