"""Write the quadratic programs Abacus.Qp's tests solve, with oracle answers.

Four problems, each in the form the library takes:

    minimize (1/2) x'P x + q'x
    subject to lo <= x <= hi and row_lo <= E x <= row_hi

* spread: 120 variables in correlation space (P a sample correlation plus
  a ridge, so its diagonal is one), each capped at 0.025, the whole
  summing to exactly one and the first 30 to at most 0.25.  The answer
  holds dozens of variables, several at their cap, and the at-most budget
  binds.
* tail: the linear program of a tail mean at 95% (the mean of the worst
  5% of 100 scenarios) over 30 columns: variables w (30, in 0 .. 0.2), the
  threshold t (no bounds) and the shortfalls u (100, at least zero);
  minimize t + sum (u) / (0.05 * 100) - 0.1 mu'w subject to
  r_s'w + t + u_s >= 0 and sum (w) = 1.  P is zero.
* tail_bounded: tail with t and u boxed as a caller who knows the data
  would pose it.  With w at least zero and summing to the budget B, a
  scenario's loss -r_s'w lies in [-B max_j r_sj, -B min_j r_sj], so the
  threshold t, a quantile of the losses, lies in [min_s (-B max_j r_sj),
  max_s (-B min_j r_sj)], and u_s = max (0, loss - t) in [0, -B min_j
  r_sj - (that least t)].  The box never binds at the answer.
* infeasible: spread with its caps at 0.008, so 120 of them cannot
  reach the budget of one, and the first 30's limit at 0.3, clear of
  the 0.25 an even spread would give them.
* nonconvex: spread with P less 2 I, whose eigenvalues are then mostly
  negative.

Every number is written as a raw integer at Frac 40 (units of 2**-40),
the problem's own numbers first rounded to that grid so the oracle sees
what the library sees; a bound of None is written as the end of the
values (+-2**57).  The oracle is OSQP at eps 1e-9 with polishing,
cross-checked against Clarabel.  OSQP does not finish the linear
program in 400,000 iterations, so its oracle is HiGHS's simplex
(scipy's linprog), cross-checked against Clarabel.  The differences go into
qp.txt with a readable copy of every answer.  Python runs only to write these files.
Usage, from the repository root:

    python tools/make_qp.py tests/data
"""

import sys
from pathlib import Path

import clarabel
import numpy as np
import osqp
import scipy.sparse as sp
from scipy.optimize import linprog

SEED = 20261006
FRAC = 40
ONE = 2.0**FRAC
OPEN = 2**57


def grid(x):
    return np.round(np.asarray(x, dtype=float) * ONE) / ONE


def raw(x):
    return np.round(np.asarray(x, dtype=float) * ONE).astype(np.int64)


def bound_raw(x):
    """A bound as raw, an infinite one as the end of the values."""
    x = np.asarray(x, dtype=float)
    out = np.where(np.isinf(x), np.sign(x) * OPEN, np.round(x * ONE))
    return out.astype(np.int64)


def correlation(rng, n, days=250, factors=3):
    loadings = rng.normal(0.0, 1.0, (n, factors))
    noise = rng.normal(0.0, 1.0, (days, n))
    returns = rng.normal(0.0, 1.0, (days, factors)) @ loadings.T + 1.5 * noise
    return np.corrcoef(returns, rowvar=False)


def spread(rng):
    n = 120
    c = correlation(rng, n)
    p = grid(c + 1e-6 * np.eye(n))
    mu = rng.normal(0.08, 0.05, n)
    q = grid(-mu / 0.5)
    lo = np.zeros(n)
    hi = np.full(n, 0.025)
    e = np.zeros((2, n))
    e[0, :] = 1.0
    e[1, :30] = 1.0
    row_lo = np.array([1.0, -np.inf])
    row_hi = np.array([1.0, 0.25])
    return dict(p=p, q=q, lo=lo, hi=hi, e=e, row_lo=row_lo, row_hi=row_hi)


def tail(rng):
    columns, scenarios, beta = 30, 100, 0.95
    r = grid(rng.normal(0.004, 0.02, (scenarios, columns)))
    mu = r.mean(axis=0)
    n = columns + 1 + scenarios
    q = np.zeros(n)
    q[:columns] = grid(-0.1 * mu)
    q[columns] = 1.0
    q[columns + 1:] = grid(1.0 / ((1.0 - beta) * scenarios))
    lo = np.concatenate([np.zeros(columns), [-np.inf], np.zeros(scenarios)])
    hi = np.concatenate([np.full(columns, 0.2), [np.inf],
                         np.full(scenarios, np.inf)])
    e = np.zeros((scenarios + 1, n))
    e[:scenarios, :columns] = r
    e[:scenarios, columns] = 1.0
    e[:scenarios, columns + 1:] = np.eye(scenarios)
    e[scenarios, :columns] = 1.0
    row_lo = np.concatenate([np.zeros(scenarios), [1.0]])
    row_hi = np.concatenate([np.full(scenarios, np.inf), [1.0]])
    return dict(p=np.zeros((n, n)), q=q, lo=lo, hi=hi, e=e,
                row_lo=row_lo, row_hi=row_hi)


def tail_bounded(pr, columns=30, scenarios=100, budget=1.0):
    """Tail with its threshold and shortfalls boxed by the data."""
    r = np.asarray(pr["e"])[:scenarios, :columns]
    worst = -budget * r.min(axis=1)
    best = -budget * r.max(axis=1)
    t_lo, t_hi = best.min(), worst.max()
    lo = np.array(pr["lo"], dtype=float)
    hi = np.array(pr["hi"], dtype=float)
    lo[columns], hi[columns] = t_lo, t_hi
    hi[columns + 1:] = worst - t_lo
    return dict(pr, lo=grid(lo), hi=grid(hi))


def solve_osqp(pr):
    n = len(pr["q"])
    a = sp.vstack([sp.eye(n), sp.csc_matrix(pr["e"])]).tocsc()
    lo = np.concatenate([pr["lo"], pr["row_lo"]])
    hi = np.concatenate([pr["hi"], pr["row_hi"]])
    s = osqp.OSQP()
    s.setup(sp.triu(sp.csc_matrix(pr["p"])).tocsc(), pr["q"], a, lo, hi,
            eps_abs=1e-9, eps_rel=1e-9, polishing=True, max_iter=400000,
            verbose=False)
    r = s.solve()
    return r.x, r.info


def solve_clarabel(pr):
    """Equalities as a zero cone, the rest as one-sided rows."""
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


def solve_highs(pr):
    """A linear program (P = 0) by HiGHS, rows split by side."""
    a = np.asarray(pr["e"])
    lo, hi = np.asarray(pr["row_lo"]), np.asarray(pr["row_hi"])
    eq = np.isfinite(lo) & np.isfinite(hi) & (lo == hi)
    up, down = np.isfinite(hi) & ~eq, np.isfinite(lo) & ~eq
    a_ub = np.vstack([a[up], -a[down]])
    b_ub = np.concatenate([hi[up], -lo[down]])
    bounds = [(None if np.isinf(l) else l, None if np.isinf(h) else h)
              for l, h in zip(pr["lo"], pr["hi"])]
    r = linprog(pr["q"], A_ub=a_ub, b_ub=b_ub, A_eq=a[eq], b_eq=lo[eq],
                bounds=bounds, method="highs")
    return r.x, r.status


def write_problem(path, name, pr, answer):
    n = len(pr["q"])
    k = len(pr["row_lo"])
    lines = [f"{name}: n k, P by rows, q, lo, hi, E by rows, row_lo, row_hi,"
             f" the oracle's x (raw at Frac {FRAC})",
             f"{n} {k}"]
    lines += [" ".join(map(str, row)) for row in raw(pr["p"])]
    for part in (raw(pr["q"]), bound_raw(pr["lo"]), bound_raw(pr["hi"])):
        lines.append(" ".join(map(str, part)))
    lines += [" ".join(map(str, row)) for row in raw(pr["e"])]
    for part in (bound_raw(pr["row_lo"]), bound_raw(pr["row_hi"])):
        lines.append(" ".join(map(str, part)))
    lines.append(" ".join(map(str, raw(answer))) if answer is not None
                 else "none")
    path.write_text("\n".join(lines) + "\n")


def report(name, pr, out, lines):
    n = len(pr["q"])
    answer = None
    try:
        x, info = solve_osqp(pr)
    except osqp.interface.OSQPException as refusal:
        lines.append(f"{name}: n {n}, k {len(pr['row_lo'])};"
                     f" OSQP refuses its setup ({refusal}): not convex;"
                     f" least eigenvalue of P"
                     f" {np.linalg.eigvalsh(pr['p']).min():.6f}")
        write_problem(out / f"qp_{name}.txt", name, pr, answer)
        return
    lines.append(f"{name}: n {n}, k {len(pr['row_lo'])};"
                 f" OSQP {info.status}, {info.iter} iterations,"
                 f" polish {info.status_polish}")
    if not np.any(pr["p"]):
        x_hi, hi_status = solve_highs(pr)
        x, status = solve_clarabel(pr)
        answer = x_hi
        lines.append(f"  linear: Clarabel {status}; HiGHS status {hi_status};"
                     f" max |Clarabel - HiGHS| = {np.max(np.abs(x - x_hi)):.3e};"
                     f" objective {pr['q'] @ x_hi:.12e} (HiGHS, the oracle);"
                     f" {int((x_hi[:30] > 1e-7).sum())} columns above zero")
        lines.append("  x: " + ", ".join(f"{v:.12f}" for v in x_hi))
    elif info.status in ("solved", "solved inaccurate"):
        x_cl, status = solve_clarabel(pr)
        answer = x
        held = int((x > 1e-7).sum())
        capped = int((np.abs(x - pr["hi"]) < 1e-7).sum())
        lines.append(f"  Clarabel {status};"
                     f" max |OSQP - Clarabel| = {np.max(np.abs(x - x_cl)):.3e};"
                     f" objective {info.obj_val:.12e};"
                     f" {held} above zero, {capped} at their upper bound")
        rows = pr["e"] @ x
        lines.append("  rows: " + ", ".join(f"{v:.12f}" for v in rows))
        lines.append("  x: " + ", ".join(f"{v:.12f}" for v in x))
    write_problem(out / f"qp_{name}.txt", name, pr, answer)


def main(out):
    out.mkdir(parents=True, exist_ok=True)
    rng = np.random.default_rng(SEED)
    base = spread(rng)
    problems = {
        "spread": base,
        "tail": tail(rng),
        "infeasible": dict(base, hi=np.full(len(base["q"]), 0.008),
                           row_hi=np.array([1.0, 0.3])),
        "nonconvex": dict(base, p=grid(base["p"] - 2.0 * np.eye(len(base["q"])))),
    }
    problems["tail_bounded"] = tail_bounded(problems["tail"])
    lines = ["abacus QP fixtures (written by tools/make_qp.py)",
             f"seed {SEED}; oracle OSQP eps 1e-9 polished, Clarabel 1e-12"]
    for name, pr in problems.items():
        report(name, pr, out, lines)
    (out / "qp.txt").write_text("\n".join(lines) + "\n")
    print("\n".join(line[:200] for line in lines))


if __name__ == "__main__":
    main(Path(sys.argv[1]))
