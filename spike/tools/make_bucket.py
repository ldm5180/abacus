"""Make the spike's synthetic bucket and its oracle answer.

One bucket: 180 assets in two blocks of 90 (block 1 and block 2), 250
days of returns, with a within-block correlation near 0.73 and a
between-block correlation near -0.26.  The problem is a mean-variance
one:

    minimize  (1/2) w'(20 S + 1e-6 I) w - mu'w
    subject to 0 <= w_i <= 1, and each block's weights sum to 0.10

where S is the sample covariance (divisor n - 1) and mu the sample mean
of the returns.  For each Frac in FRACS the returns are rounded to the
grid 2**-Frac, and the oracle is computed from THOSE returns, so the
Ada side and the oracle see the same inputs.

The oracle is OSQP at eps_abs = eps_rel = 1e-9 with polishing.  It is
cross-checked against Clarabel (an interior-point method) and against
an exact solve of the KKT system on OSQP's active set, whose multiplier
signs are then checked; the differences go into bucket.txt.

Python runs only to make these files.  Usage, from the repository root:

    python spike/tools/make_bucket.py spike/tests/data
"""

import sys
from pathlib import Path

import clarabel
import numpy as np
import osqp
import scipy.sparse as sp

SEED = 20261006
DAYS = 250
BLOCK = 90
ASSETS = 2 * BLOCK
WITHIN = 0.73
BETWEEN = -0.26
SKEW = 0.15
LAMBDA = 20.0
RIDGE = 1e-6
BUDGET = 0.10
FRACS = (32, 40, 48)


def population_correlation():
    c = np.full((ASSETS, ASSETS), BETWEEN)
    c[:BLOCK, :BLOCK] = WITHIN
    c[BLOCK:, BLOCK:] = WITHIN
    np.fill_diagonal(c, 1.0)
    return c


def make_returns(rng):
    """Daily returns per unit of risk: mean near +0.005, fat left tail."""
    chol = np.linalg.cholesky(population_correlation())
    z = rng.standard_normal((DAYS, ASSETS)) @ chol.T
    u = (z - SKEW * (z * z - 1.0)) / np.sqrt(1.0 + 2.0 * SKEW * SKEW)
    mean = rng.uniform(0.002, 0.008, ASSETS)
    std = rng.uniform(0.03, 0.07, ASSETS)
    return mean + std * u


def problem(returns):
    mu = returns.mean(axis=0)
    cov = np.cov(returns, rowvar=False, ddof=1)
    p = LAMBDA * cov + RIDGE * np.eye(ASSETS)
    e = np.zeros((2, ASSETS))
    e[0, :BLOCK] = 1.0
    e[1, BLOCK:] = 1.0
    return p, -mu, e


def solve_osqp(p, q, e):
    a = sp.vstack([sp.eye(ASSETS), sp.csc_matrix(e)]).tocsc()
    lo = np.concatenate([np.zeros(ASSETS), np.full(2, BUDGET)])
    hi = np.concatenate([np.ones(ASSETS), np.full(2, BUDGET)])
    s = osqp.OSQP()
    s.setup(
        sp.triu(sp.csc_matrix(p)).tocsc(), q, a, lo, hi,
        eps_abs=1e-9, eps_rel=1e-9, polishing=True, max_iter=200000,
        verbose=False)
    r = s.solve()
    return r.x, r.info


def solve_clarabel(p, q, e):
    # Rows: the two equalities (zero cone), then -w <= 0 and w <= 1.
    a = sp.vstack(
        [sp.csc_matrix(e), -sp.eye(ASSETS), sp.eye(ASSETS)]).tocsc()
    b = np.concatenate([np.full(2, BUDGET), np.zeros(ASSETS),
                        np.ones(ASSETS)])
    cones = [clarabel.ZeroConeT(2), clarabel.NonnegativeConeT(2 * ASSETS)]
    settings = clarabel.DefaultSettings()
    settings.verbose = False
    settings.tol_gap_abs = 1e-14
    settings.tol_gap_rel = 1e-14
    settings.tol_feas = 1e-14
    settings.max_iter = 500
    s = clarabel.DefaultSolver(
        sp.triu(sp.csc_matrix(p)).tocsc(), q, a, b, cones, settings)
    r = s.solve()
    return np.array(r.x), str(r.status)


def kkt_on_active_set(p, q, e, w):
    """Solve the KKT system exactly on w's active set; check its signs."""
    lower = w < 1e-7
    upper = w > 1.0 - 1e-7
    free = ~(lower | upper)
    fixed = np.where(upper, 1.0, 0.0)
    pf = p[np.ix_(free, free)]
    ef = e[:, free]
    rhs_x = -q[free] - p[np.ix_(free, ~free)] @ fixed[~free]
    rhs_e = np.full(2, BUDGET) - e[:, ~free] @ fixed[~free]
    nf = pf.shape[0]
    kkt = np.block([[pf, ef.T], [ef, np.zeros((2, 2))]])
    sol = np.linalg.solve(kkt, np.concatenate([rhs_x, rhs_e]))
    x = fixed.copy()
    x[free] = sol[:nf]
    nu = sol[nf:]
    # Gradient of the Lagrangian on the bound-held variables: at a lower
    # bound it must be >= 0, at an upper bound <= 0.
    g = p @ x + q + e.T @ nu
    sign_ok = bool(np.all(g[lower] >= -1e-12) and np.all(g[upper] <= 1e-12))
    box_ok = bool(np.all(x[free] >= 0.0) and np.all(x[free] <= 1.0))
    return x, int(free.sum()), sign_ok and box_ok, float(np.min(g[lower]))


def write_ints(path, header, values):
    with open(path, "w") as f:
        f.write(header + "\n")
        for row in np.atleast_2d(values):
            f.write(" ".join(str(int(v)) for v in row) + "\n")


def to_raw(x, frac):
    return np.round(x * 2.0**frac).astype(np.int64)


def main(out):
    out.mkdir(parents=True, exist_ok=True)
    rng = np.random.default_rng(SEED)
    returns = make_returns(rng)
    lines = [
        "abacus spike bucket (written by spike/tools/make_bucket.py)",
        f"seed {SEED}, {DAYS} days, {ASSETS} assets, blocks 1..{BLOCK} "
        f"and {BLOCK + 1}..{ASSETS}",
        f"problem: minimize (1/2) w'({LAMBDA:g} S + {RIDGE:g} I) w - mu'w,"
        f" 0 <= w <= 1, each block sums to {BUDGET:g}",
        "S: sample covariance, divisor n - 1; mu: sample mean",
    ]
    corr = np.corrcoef(returns, rowvar=False)
    blk = np.zeros((ASSETS, ASSETS), dtype=bool)
    blk[:BLOCK, :BLOCK] = blk[BLOCK:, BLOCK:] = True
    off = ~np.eye(ASSETS, dtype=bool)
    lines.append(
        f"median correlation: within {np.median(corr[blk & off]):.4f},"
        f" between {np.median(corr[~blk]):.4f}")
    lines.append(
        f"returns: mean {returns.mean():.5f}, std {returns.std():.5f},"
        f" min {returns.min():.4f}, max {returns.max():.4f}")
    for frac in FRACS:
        raw = to_raw(returns, frac)
        rq = raw / 2.0**frac
        p, q, e = problem(rq)
        w_osqp, info = solve_osqp(p, q, e)
        w_cl, cl_status = solve_clarabel(p, q, e)
        w_kkt, nfree, kkt_ok, gmin = kkt_on_active_set(p, q, e, w_osqp)
        write_ints(out / f"returns_f{frac}.txt", f"{DAYS} {ASSETS}", raw)
        write_ints(out / f"weights_f{frac}.txt", f"{ASSETS}",
                   to_raw(w_osqp, frac))
        lines.append("")
        lines.append(f"Frac {frac}:")
        lines.append(
            f"  OSQP: {info.status}, {info.iter} iterations, polish"
            f" status {info.status_polish}, objective {info.obj_val:.12e}")
        lines.append(f"  Clarabel: {cl_status}")
        lines.append(
            f"  max |OSQP - Clarabel| = {np.max(np.abs(w_osqp - w_cl)):.3e}")
        lines.append(
            f"  max |OSQP - KKT on active set| ="
            f" {np.max(np.abs(w_osqp - w_kkt)):.3e}; {nfree} free;"
            f" KKT signs and box hold: {kkt_ok}; least lower-bound"
            f" multiplier {gmin:.3e}")
        lines.append("  oracle weights (OSQP), nonzero:")
        for i in np.nonzero(w_osqp > 1e-9)[0]:
            lines.append(f"    w[{i + 1}] = {w_osqp[i]:.12f}")
    (out / "bucket.txt").write_text("\n".join(lines) + "\n")
    print("\n".join(lines))


if __name__ == "__main__":
    main(Path(sys.argv[1]))
