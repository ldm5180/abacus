"""Write the ratio program Abacus.Qp's tests solve, with its oracle.

The ratio program maximizes a mean over a deviation, m'w / sqrt (w'C w),
over w >= 0 with each of two parts summing to a budget and each w_i at
most a cap.  The ratio does not change when w is scaled, so the program
is posed homogenized: y = k w for a scale k >= 0, the mean fixed at one,
and the deviation minimized:

    minimize (1/2) y'C y
    subject to y >= 0, k >= 0,
               m'y = 1                          (the mean row)
               sum over part g of y_i - k = 0   (one row per part)
               y_i - cap k <= 0                 (one row per variable)

and w = y / k.  It is posed as its first consumer poses it, in
correlation space: y_i stands for d_i times its weight, d_i a
variable's deviation over their geometric mean (so a row's entries are
1 / d_i, between about 0.5 and 2), C the correlation, and the mean row
m_i / (d_i max m), its entries from a thousandth to about one.  The cap
is ten budgets, so no cap row binds: the k column holds -10 in each of
them, and its norm is about ten times the root of n where every other
column's is about one.  That scale gap, and a mean row of small
entries, are what the fixture is for.

The data are synthetic and seeded: 150 variables in two parts of 75,
250 draws of three common factors with loadings around 0.8, 0.3 and 0.25
plus each variable's own noise, so the correlation's mean is about 0.4
and its largest eigenvalue about 60; deviations lognormal; means normal
about zero, times the deviation.

The oracle: Clarabel at 1e-12, then an exact solve of the optimality
conditions on the bounds and rows its answer holds -- the linear system

    C_FF y_F + A_F' lambda = 0,  A_F y_F = b,

over the free variables F and the held rows A (the mean and part rows,
and any cap row at its bound) -- checked by the held bounds' multipliers
having their sign.  The exact solve is the answer the fixture holds.

Every number of the problem is written as a raw integer at Frac 40
(units of 2**-40), the problem first rounded to that grid so the oracle
solves what the library is given; an open bound as the end of the values
(+-2**57).  qp_ratio.txt holds the problem and the answer; ratio.txt the
report.  Python runs only to write these files.  Usage, from the
repository root:

    python tools/make_ratio.py tests/data
"""

import sys
from pathlib import Path

import clarabel
import numpy as np
import scipy.sparse as sp

SEED = 20261008
FRAC = 40
ONE = 2.0**FRAC
OPEN = 2**57
N, PARTS, DRAWS, CAP = 150, 2, 250, 10.0


def grid(x):
    return np.round(np.asarray(x, dtype=float) * ONE) / ONE


def raw(x):
    return np.round(np.asarray(x, dtype=float) * ONE).astype(np.int64)


def bound_raw(x):
    """A bound as raw, an infinite one as the end of the values."""
    x = np.asarray(x, dtype=float)
    out = np.where(np.isinf(x), np.sign(x) * OPEN, np.round(x * ONE))
    return out.astype(np.int64)


def data(rng):
    """The correlation, the deviations' ratios d and the means."""
    factors = rng.normal(0.0, 1.0, (DRAWS, 3))
    loadings = rng.normal(0.8, 0.3, (N, 3)) * np.array([1.0, 0.4, 0.3])
    draws = factors @ loadings.T + rng.normal(0.0, 1.0, (DRAWS, N))
    deviation = np.exp(rng.normal(0.0, 0.35, N))
    mean = rng.normal(0.0, 0.08, N) * deviation
    d = deviation / np.exp(np.mean(np.log(deviation)))
    return np.corrcoef(draws, rowvar=False), d, mean


def problem(c, d, mean):
    """The homogenized program over x = (y, k)."""
    n = N + 1
    part = np.arange(N) * PARTS // N
    p = np.zeros((n, n))
    p[:N, :N] = grid(c)
    e = np.zeros((1 + PARTS + N, n))
    e[0, :N] = grid(mean / mean.max() / d)
    for g in range(PARTS):
        e[1 + g, :N] = np.where(part == g, grid(1.0 / d), 0.0)
        e[1 + g, N] = -1.0
    e[1 + PARTS:, :N] = np.diag(grid(1.0 / d))
    e[1 + PARTS:, N] = -CAP
    row_lo = np.concatenate([[1.0], np.zeros(PARTS), np.full(N, -np.inf)])
    row_hi = np.concatenate([[1.0], np.zeros(PARTS), np.zeros(N)])
    return dict(p=p, q=np.zeros(n), lo=np.zeros(n), hi=np.full(n, np.inf),
                e=e, row_lo=row_lo, row_hi=row_hi)


def solve_clarabel(pr):
    """Equalities as a zero cone, the one-sided rows as nonnegatives."""
    n = len(pr["q"])
    a = np.vstack([np.eye(n), pr["e"]])
    lo = np.concatenate([pr["lo"], pr["row_lo"]])
    hi = np.concatenate([pr["hi"], pr["row_hi"]])
    eq = np.isfinite(lo) & np.isfinite(hi) & (lo == hi)
    up = np.isfinite(hi) & ~eq
    down = np.isfinite(lo) & ~eq
    rows = [sp.csc_matrix(a[eq]), sp.csc_matrix(a[up]),
            sp.csc_matrix(-a[down])]
    b = np.concatenate([hi[eq], hi[up], -lo[down]])
    cones = [clarabel.ZeroConeT(int(eq.sum())),
             clarabel.NonnegativeConeT(int(up.sum() + down.sum()))]
    settings = clarabel.DefaultSettings()
    settings.verbose = False
    settings.tol_gap_abs = settings.tol_gap_rel = 1e-12
    settings.tol_feas = 1e-12
    settings.max_iter = 500
    s = clarabel.DefaultSolver(sp.triu(sp.csc_matrix(pr["p"])).tocsc(),
                               pr["q"], sp.vstack(rows).tocsc(), b, cones,
                               settings)
    r = s.solve()
    return np.array(r.x), str(r.status)


def exact(pr, start):
    """The optimality conditions solved on the bounds start holds."""
    p, e = pr["p"], pr["e"]
    free = np.where(start > 1e-7)[0]
    rows = e @ start
    held = np.where(np.isfinite(pr["row_lo"])
                    | (np.abs(rows - pr["row_hi"]) < 1e-7))[0]
    a = e[np.ix_(held, free)]
    b = np.where(np.isfinite(pr["row_lo"][held]), pr["row_lo"][held],
                 pr["row_hi"][held])
    kkt = np.block([[p[np.ix_(free, free)], a.T],
                    [a, np.zeros((len(held), len(held)))]])
    rhs = np.concatenate([-pr["q"][free], b])
    sol = np.linalg.solve(kkt, rhs)
    x = np.zeros(len(pr["q"]))
    x[free] = sol[:len(free)]
    lam = np.zeros(len(pr["row_lo"]))
    lam[held] = sol[len(free):]
    gradient = p @ x + pr["q"] + e.T @ lam
    at_zero = np.setdiff1d(np.arange(len(x)), free)
    return x, lam, np.abs(gradient[free]).max(), gradient[at_zero]


def write_problem(path, pr, answer):
    n, k = len(pr["q"]), len(pr["row_lo"])
    lines = [f"ratio: n k, P by rows, q, lo, hi, E by rows, row_lo, row_hi,"
             f" the oracle's x (raw at Frac {FRAC})",
             f"{n} {k}"]
    lines += [" ".join(map(str, row)) for row in raw(pr["p"])]
    for part in (raw(pr["q"]), bound_raw(pr["lo"]), bound_raw(pr["hi"])):
        lines.append(" ".join(map(str, part)))
    lines += [" ".join(map(str, row)) for row in raw(pr["e"])]
    for part in (bound_raw(pr["row_lo"]), bound_raw(pr["row_hi"])):
        lines.append(" ".join(map(str, part)))
    lines.append(" ".join(map(str, raw(answer))))
    path.write_text("\n".join(lines) + "\n")


def main(out):
    out.mkdir(parents=True, exist_ok=True)
    c, d, mean = data(np.random.default_rng(SEED))
    pr = problem(c, d, mean)
    x_cl, status = solve_clarabel(pr)
    x, lam, stationary, pulls = exact(pr, x_cl)
    free = np.where(x > 0)[0]
    report = [
        "abacus ratio fixture (written by tools/make_ratio.py)",
        f"seed {SEED}; n {N} in {PARTS} parts, cap {CAP:g} budgets;"
        f" x = (y, k), {N + 1} variables, {1 + PARTS + N} rows",
        f"  correlation: mean {c[np.triu_indices(N, 1)].mean():.4f},"
        f" largest eigenvalue {np.linalg.eigvalsh(c).max():.4f};"
        f" d in [{d.min():.4f}, {d.max():.4f}];"
        f" the mean row's entries in [{np.abs(pr['e'][0]).min():.6f},"
        f" {np.abs(pr['e'][0]).max():.6f}]",
        f"  Clarabel {status}; max |Clarabel - exact| ="
        f" {np.abs(x_cl - x).max():.3e}",
        f"  exact: stationarity {stationary:.3e}; {len(free) - 1} variables"
        f" above zero and k; least multiplier of a bound held at zero"
        f" {pulls.min():.6f} (must be >= 0)",
        f"  objective {0.5 * x @ pr['p'] @ x:.12e}; k {x[N]:.12f};"
        f" the rows' multipliers {', '.join(f'{v:.9f}' for v in lam[:3])}",
        "  y / k above zero: "
        + ", ".join(f"{i + 1}: {x[i] / x[N]:.12f}" for i in free if i < N),
    ]
    write_problem(out / "qp_ratio.txt", pr, x)
    (out / "ratio.txt").write_text("\n".join(report) + "\n")
    print("\n".join(report))


if __name__ == "__main__":
    main(Path(sys.argv[1]))
