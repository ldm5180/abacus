"""Write the ticked tail program Abacus.Qp's tests solve, with its oracle.

The tail-mean linear program of make_qp.py's tail, at the size and in
the shape its first consumer poses it -- 164 columns, 153 scenarios, two
parts each summing to 0.094, the threshold and the shortfalls boxed by
the data -- with outcomes that lie on a grid of ticks of 0.005: most a
small gain, one in five a loss, one in five exactly zero, and a few
scenarios where most columns lose together.  Ties among the outcomes
make the program's vertex near-degenerate: ADMM's held set comes within
a few bounds of the answer's early and then cannot tell them apart for
tens of thousands of iterations (the polish's corrections certify it at
25,200), which is what the crossover is for.

    minimize -m'w + a + sum (u) / ((1 - beta) T)
    subject to r_s'w + a + u_s >= 0 (one row per scenario),
               each part's sum of w equal to 0.094 (one row per part),
               0 <= w <= 1, a and u boxed by the data,

m the columns' means, beta 0.95, T the scenarios.  The box is the one
tail_bounded explains: a between the least and the most loss a scenario
can bring at the whole budget, each u from zero to the most less a's
least.

The oracle: HiGHS's simplex, then the vertex it names solved exactly --
its held bounds and rows taken as equalities, a square linear system --
checked by every free constraint lying inside its bounds.  Every number
is written as a raw integer at Frac 40, the problem rounded to that grid
first; an open bound as the end of the values (+-2**57).
qp_ticked.txt holds the problem and the answer; ticked.txt the report.
Python runs only to write these files.  Usage, from the repository root:

    python tools/make_ticked.py tests/data
"""

import sys
from pathlib import Path

import numpy as np
from scipy.optimize import linprog

SEED = 34
FRAC = 40
ONE = 2.0**FRAC
OPEN = 2**57
COLUMNS, SCENARIOS, PARTS = 164, 153, 2
BUDGET, BETA, TICK = 0.094, 0.95, 0.005


def grid(x):
    return np.round(np.asarray(x, dtype=float) * ONE) / ONE


def raw(x):
    return np.round(np.asarray(x, dtype=float) * ONE).astype(np.int64)


def bound_raw(x):
    """A bound as raw, an infinite one as the end of the values."""
    x = np.asarray(x, dtype=float)
    out = np.where(np.isinf(x), np.sign(x) * OPEN, np.round(x * ONE))
    return out.astype(np.int64)


def outcomes(rng):
    """Scenarios by columns, on the tick grid."""
    gain = rng.normal(0.03, 0.02, (SCENARIOS, COLUMNS))
    loss = -np.abs(rng.normal(0.08, 0.07, (SCENARIOS, COLUMNS)))
    r = np.where(rng.random((SCENARIOS, COLUMNS)) < 0.8, gain, loss)
    common = rng.normal(0, 1, SCENARIOS)[:, None]
    r = np.where(common < -1.2, loss, r)
    r = np.where(rng.random((SCENARIOS, COLUMNS)) < 0.21, 0.0, r)
    return np.clip(np.round(r / TICK) * TICK, -0.29, 0.13)


def problem(r):
    n, k = COLUMNS + 1 + SCENARIOS, SCENARIOS + PARTS
    q = np.zeros(n)
    q[:COLUMNS] = grid(-r.mean(axis=0))
    q[COLUMNS] = 1.0
    q[COLUMNS + 1:] = grid(1.0 / ((1.0 - BETA) * SCENARIOS))
    whole = BUDGET * PARTS
    worst, best = -whole * r.min(axis=1), -whole * r.max(axis=1)
    lo, hi = np.zeros(n), np.ones(n)
    lo[COLUMNS], hi[COLUMNS] = best.min(), worst.max()
    hi[COLUMNS + 1:] = worst.max() - best.min()
    e = np.zeros((k, n))
    e[:SCENARIOS, :COLUMNS] = r
    e[:SCENARIOS, COLUMNS] = 1.0
    e[:SCENARIOS, COLUMNS + 1:] = np.eye(SCENARIOS)
    part = np.arange(COLUMNS) * PARTS // COLUMNS
    for g in range(PARTS):
        e[SCENARIOS + g, :COLUMNS] = (part == g)
    row_lo = np.concatenate([np.zeros(SCENARIOS), np.full(PARTS, BUDGET)])
    row_hi = np.concatenate([np.full(SCENARIOS, np.inf),
                             np.full(PARTS, BUDGET)])
    return dict(q=q, lo=grid(lo), hi=grid(hi), e=grid(e),
                row_lo=grid(row_lo), row_hi=row_hi)


def solve_highs(pr):
    a, lo, hi = pr["e"], pr["row_lo"], pr["row_hi"]
    eq = np.isfinite(lo) & np.isfinite(hi) & (lo == hi)
    up, down = np.isfinite(hi) & ~eq, np.isfinite(lo) & ~eq
    r = linprog(pr["q"], A_ub=np.vstack([a[up], -a[down]]),
                b_ub=np.concatenate([hi[up], -lo[down]]), A_eq=a[eq],
                b_eq=lo[eq], bounds=list(zip(pr["lo"], pr["hi"])),
                method="highs")
    return r.x, r.status


def exact(pr, start, tol=1e-9):
    """The vertex start names, solved from its held bounds and rows."""
    e, lo, hi = pr["e"], pr["lo"], pr["hi"]
    at_lo, at_hi = np.abs(start - lo) < tol, np.abs(start - hi) < tol
    free = ~(at_lo | at_hi)
    x = np.where(at_hi, hi, np.where(at_lo, lo, 0.0))
    rows = e @ start
    r_lo = np.abs(rows - pr["row_lo"]) < tol
    r_hi = np.isfinite(pr["row_hi"]) & (np.abs(rows - pr["row_hi"]) < tol)
    held = r_lo | r_hi
    b = np.where(r_lo, pr["row_lo"], pr["row_hi"])[held]
    a = e[np.ix_(held, free)]
    x[free] = np.linalg.solve(a, b - e[np.ix_(held, ~free)] @ x[~free])
    return x, int(free.sum()), int(held.sum())


def write_problem(path, pr, answer):
    n, k = len(pr["q"]), len(pr["row_lo"])
    lines = [f"ticked: n k, P by rows, q, lo, hi, E by rows, row_lo, row_hi,"
             f" the oracle's x (raw at Frac {FRAC})",
             f"{n} {k}"]
    lines += [" ".join(["0"] * n)] * n
    for part in (raw(pr["q"]), bound_raw(pr["lo"]), bound_raw(pr["hi"])):
        lines.append(" ".join(map(str, part)))
    lines += [" ".join(map(str, row)) for row in raw(pr["e"])]
    for part in (bound_raw(pr["row_lo"]), bound_raw(pr["row_hi"])):
        lines.append(" ".join(map(str, part)))
    lines.append(" ".join(map(str, raw(answer))))
    path.write_text("\n".join(lines) + "\n")


def main(out):
    out.mkdir(parents=True, exist_ok=True)
    r = outcomes(np.random.default_rng(SEED))
    pr = problem(r)
    x_hi, status = solve_highs(pr)
    x, free, held = exact(pr, x_hi)
    rows = pr["e"] @ x
    outside = max(np.maximum(pr["lo"] - x, 0).max(),
                  np.maximum(x - pr["hi"], 0).max(),
                  np.maximum(pr["row_lo"] - rows, 0).max(),
                  np.maximum(rows - pr["row_hi"], 0).max())
    ties = r.size - len(np.unique(r))
    report = [
        "abacus ticked tail fixture (written by tools/make_ticked.py)",
        f"seed {SEED}; {COLUMNS} columns, {SCENARIOS} scenarios, {PARTS}"
        f" parts at {BUDGET}; outcomes on ticks of {TICK}, {ties} of"
        f" {r.size} repeating another",
        f"  HiGHS status {status}; the exact vertex {free} free variables"
        f" over {held} held rows, max |HiGHS - exact| ="
        f" {np.abs(x_hi - x).max():.3e}, the furthest outside {outside:.3e}",
        f"  objective {pr['q'] @ x:.12e}; columns above zero:"
        f" {int((x[:COLUMNS] > 1e-9).sum())}",
    ]
    write_problem(out / "qp_ticked.txt", pr, x)
    (out / "ticked.txt").write_text("\n".join(report) + "\n")
    print("\n".join(report))


if __name__ == "__main__":
    main(Path(sys.argv[1]))
