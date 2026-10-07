"""Write the second-order cone program Abacus.Qp's tests solve, with oracles.

The deviation program, at the shape statera's first consumer solves it:
T = 1,500 outcomes of n = 14 columns in a table P, and

    maximize mean (P w) - lambda ||P w - mean (P w) 1|| / sqrt (T)
    subject to 0 <= w <= 20 and sum (w) = 10, lambda = 75,

posed in epigraph form over x = (w, t):

    minimize -m'w + lambda t
    subject to 0 <= w <= 20, t open, sum (w) = 10 (an interval row),
               ||G w|| <= t (a cone: a head row picking t, and G's rows),

with m the columns' means and G = (P - 1 m') / sqrt (T).

The table is synthetic and seeded: three common factors (Student t, five
degrees of freedom) with loadings drawn per column, three columns loaded
heavily on the first, plus each column's own Student t noise (four
degrees) and a small drift.  It is drawn in large units (tens of
thousands) and then divided by one constant, the standard deviation of
every entry together.  Dividing the whole table by one positive constant
scales both terms of the objective alike, so the answer w does not move
(t scales with it); that is how a caller brings its data well inside the
values abacus holds.  m and G are formed from the table rounded to the
grid, and rounded to the grid themselves, so the oracle solves exactly
what the library is given.

The oracle: Clarabel (tolerances 1e-10, its direct second-order cone)
and ECOS (1e-12), and then an exact solve of the optimality conditions
on the bounds Clarabel's answer holds -- Newton on

    lambda G_F' G w / ||G w|| - m_F + nu 1 = 0,  sum (w_F) = 10,

w zero off F -- to the last place, checked by the held bounds'
multipliers being nonnegative.  The conic solvers agree with each other,
and with the exact solve, only to about 1e-6 in the weights: the
objective is flat along the budget near its answer.  The exact solve is
the answer the fixture holds.

Every number of the problem is written as a raw integer at Frac 40
(units of 2**-40); an open bound as the end of the values (+-2**57).
qp_deviation.txt holds the problem and the answer; socp.txt the report
and a readable copy: the table P as divided, m, and the answer, in
decimals.  Python runs only to write these files.  Usage, from the
repository root:

    python tools/make_socp.py tests/data
"""

import sys
from pathlib import Path

import clarabel
import ecos
import numpy as np
import scipy.sparse as sp

SEED = 20261006
FRAC = 40
ONE = 2.0**FRAC
OPEN = 2**57
T, N = 1500, 14
LAMBDA, CAP, BUDGET = 75.0, 20.0, 10.0
INTERVAL, HEAD, TAIL = 0, 1, 2


def grid(x):
    return np.round(np.asarray(x, dtype=float) * ONE) / ONE


def raw(x):
    return np.round(np.asarray(x, dtype=float) * ONE).astype(np.int64)


def bound_raw(x):
    x = np.asarray(x, dtype=float)
    out = np.where(np.isinf(x), np.sign(x) * OPEN, np.round(x * ONE))
    return out.astype(np.int64)


def table(rng):
    """The outcomes, drawn in large units, then divided by one constant."""
    load = rng.normal(0.0, 0.5, (3, N))
    load[0, [3, 9, 12]] = 2.0
    common = rng.standard_t(5, (T, 3)) @ load
    spread = rng.uniform(0.6, 1.6, N)
    spread[[3, 9, 12]] *= 1.5
    own = rng.standard_t(4, (T, N)) * spread
    drift = rng.uniform(0.0, 0.12, N)
    drawn = 40000.0 * (common + own + drift)
    return grid(drawn / drawn.std()), drawn.std()


def problem(p):
    m = grid(p.mean(axis=0))
    g = grid((p - p.mean(axis=0)) / np.sqrt(T))
    n = N + 1
    e = np.zeros((2 + T, n))
    e[0, :N] = 1.0
    e[1, N] = 1.0
    e[2:, :N] = g
    return dict(
        p=np.zeros((n, n)),
        q=np.concatenate([-m, [LAMBDA]]),
        lo=np.concatenate([np.zeros(N), [-np.inf]]),
        hi=np.concatenate([np.full(N, CAP), [np.inf]]),
        e=e,
        row_lo=np.concatenate([[BUDGET], np.zeros(T + 1)]),
        row_hi=np.concatenate([[BUDGET], np.full(T + 1, np.inf)]),
        kind=np.array([INTERVAL, HEAD] + [TAIL] * T),
        m=m, g=g)


def conic_rows(pr):
    """The program as s = b - A x: the budget, the box, then the cone."""
    n = N + 1
    a_box = np.vstack([np.hstack([-np.eye(N), np.zeros((N, 1))]),
                       np.hstack([np.eye(N), np.zeros((N, 1))])])
    a = np.vstack([pr["e"][:1], a_box, -pr["e"][1:]])
    b = np.concatenate([[BUDGET], np.zeros(N), np.full(N, CAP),
                        np.zeros(T + 1)])
    return sp.csc_matrix(a), b, n


def solve_clarabel(pr):
    a, b, n = conic_rows(pr)
    settings = clarabel.DefaultSettings()
    settings.verbose = False
    settings.tol_gap_abs = settings.tol_gap_rel = 1e-10
    settings.tol_feas = 1e-10
    settings.max_iter = 500
    cones = [clarabel.ZeroConeT(1), clarabel.NonnegativeConeT(2 * N),
             clarabel.SecondOrderConeT(T + 1)]
    r = clarabel.DefaultSolver(sp.csc_matrix((n, n)), pr["q"], a, b, cones,
                               settings).solve()
    return np.array(r.x), f"{r.status}, {r.iterations} iterations"


def solve_ecos(pr):
    a, b, _ = conic_rows(pr)
    r = ecos.solve(pr["q"], a[1:], b[1:], {"l": 2 * N, "q": [T + 1]},
                   A=a[:1], b=b[:1], abstol=1e-12, reltol=1e-12,
                   feastol=1e-12, max_iters=500, verbose=False)
    return r["x"], f"{r['info']['infostring']}, {r['info']['iter']} iterations"


def exact(pr, start):
    """Newton on the optimality conditions over the bounds start holds."""
    g, m = pr["g"], pr["m"]
    free = np.where(start[:N] > 1e-6)[0]
    w = np.where(start[:N] > 1e-6, start[:N], 0.0)
    nu = 0.0
    for _ in range(50):
        gw = g @ w
        r = np.linalg.norm(gw)
        u = g.T @ gw
        grad = LAMBDA * u / r - m
        hess = LAMBDA * (g.T @ g / r - np.outer(u, u) / r**3)
        res = np.concatenate([grad[free] + nu, [w[free].sum() - BUDGET]])
        k = len(free)
        kkt = np.zeros((k + 1, k + 1))
        kkt[:k, :k] = hess[np.ix_(free, free)]
        kkt[:k, k] = kkt[k, :k] = 1.0
        step = np.linalg.solve(kkt, -res)
        w[free] += step[:k]
        nu += step[k]
    gw = g @ w
    grad = LAMBDA * g.T @ gw / np.linalg.norm(gw) - m
    held = np.setdiff1d(np.arange(N), free)
    return (np.concatenate([w, [np.linalg.norm(gw)]]),
            np.abs(grad[free] + nu).max(), grad[held] + nu, held)


def write_problem(path, pr, answer):
    n, k = len(pr["q"]), len(pr["row_lo"])
    lines = [f"deviation: n k, P by rows, q, lo, hi, E by rows, row_lo,"
             f" row_hi, the rows' kinds (0 interval, 1 cone head, 2 cone"
             f" tail), the oracle's x (raw at Frac {FRAC})",
             f"{n} {k}"]
    lines += [" ".join(map(str, row)) for row in raw(pr["p"])]
    for part in (raw(pr["q"]), bound_raw(pr["lo"]), bound_raw(pr["hi"])):
        lines.append(" ".join(map(str, part)))
    lines += [" ".join(map(str, row)) for row in raw(pr["e"])]
    for part in (bound_raw(pr["row_lo"]), bound_raw(pr["row_hi"])):
        lines.append(" ".join(map(str, part)))
    lines.append(" ".join(map(str, pr["kind"])))
    lines.append(" ".join(map(str, raw(answer))))
    path.write_text("\n".join(lines) + "\n")


def decimals(v):
    return " ".join(f"{x:.12f}" for x in v)


def main(out):
    out.mkdir(parents=True, exist_ok=True)
    p, divisor = table(np.random.default_rng(SEED))
    pr = problem(p)
    x_cl, st_cl = solve_clarabel(pr)
    x_ec, st_ec = solve_ecos(pr)
    x, stationary, pulls, held = exact(pr, x_cl)
    obj = pr["q"] @ x
    report = [
        "abacus SOCP fixture (written by tools/make_socp.py)",
        f"seed {SEED}; T {T}, n {N}, lambda {LAMBDA:g}, 0 <= w <= {CAP:g},"
        f" sum (w) = {BUDGET:g}; the table divided by {divisor:.6f}",
        f"deviation: x = (w, t), n {N + 1}, k {T + 2} (a budget row, a cone"
        f" of {T + 1} rows)",
        f"  Clarabel {st_cl}; ECOS {st_ec}",
        f"  max |Clarabel - exact| = {np.abs(x_cl - x)[:N].max():.3e};"
        f" max |ECOS - exact| = {np.abs(x_ec - x)[:N].max():.3e};"
        f" max |Clarabel - ECOS| = {np.abs(x_cl - x_ec)[:N].max():.3e}"
        " (weights)",
        f"  exact: stationarity {stationary:.3e}; held at zero:"
        f" {', '.join(str(i + 1) for i in held)}, their multipliers"
        f" {', '.join(f'{v:.6f}' for v in pulls)} (each must be >= 0)",
        f"  objective {obj:.12e}; mean {pr['m'] @ x[:N]:.12f};"
        f" deviation t {x[N]:.12f}",
        "  w: " + ", ".join(f"{v:.12f}" for v in x[:N]),
        "",
        "the readable copy: m, then the table P as divided (T rows of n),"
        " then the answer x = (w, t)",
        decimals(pr["m"]),
    ]
    report += [decimals(row) for row in p]
    report.append(decimals(x))
    write_problem(out / "qp_deviation.txt", pr, x)
    (out / "socp.txt").write_text("\n".join(report) + "\n")
    print("\n".join(report[:8]))


if __name__ == "__main__":
    main(Path(sys.argv[1]))
