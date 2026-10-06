"""Write the oracle fixture for Abacus.Elementary's tests.

Each line is "<function> <input> <definition> <true>": raw integers at
Frac 40 (units of 2**-40).  <definition> is the function's own
definition evaluated in 60-digit decimal arithmetic and rounded to the
grid -- for exp, log and sqrt the exact function; for the normal CDF
the Abramowitz-Stegun 26.2.17 approximation the library implements;
for its inverse Wichura's AS 241 (PPND16).  <true> is the function
itself as scipy computes it in binary64, rounded to the grid, for the
approximations' stated errors.

The inputs are seeded, so the file is the same on every run.  Python
runs only to write this file; nothing runs it at build or test time.
Usage, from the repository root:

    python tools/make_elementary.py tests/data/elementary.txt
"""

import math
import sys
from decimal import Decimal, getcontext
from pathlib import Path

import numpy as np
from scipy import special

SEED = 20261006
FRAC = 40
ONE = 2**FRAC
VAL_BOUND = 2**57
COUNT = 400

getcontext().prec = 60
D_ONE = Decimal(ONE)


def to_raw(d):
    """The grid value nearest a Decimal, ties away from zero."""
    scaled = d * D_ONE
    whole = int(abs(scaled) + Decimal("0.5"))
    return whole if scaled >= 0 else -whole


def as_decimal(raw):
    return Decimal(raw) / D_ONE


# Abramowitz-Stegun 26.2.17, as Abacus.Elementary writes it.
AS_P = Decimal("0.2316419")
AS_B = [Decimal(s) for s in (
    "0.319381530", "-0.356563782", "1.781477937", "-1.821255978",
    "1.330274429")]
def pi_decimal():
    """pi to the context's precision (Machin's formula)."""
    getcontext().prec += 5

    def arctan_inv(x):
        x = Decimal(x)
        total = term = 1 / x
        n, sign, x2 = 1, -1, x * x
        while True:
            term /= x2
            n += 2
            add = sign * term / n
            if add == 0:
                break
            total += add
            sign = -sign
        return total

    result = 4 * (4 * arctan_inv(5) - arctan_inv(239))
    getcontext().prec -= 5
    return +result


PI = pi_decimal()
INV_SQRT_2PI = 1 / (2 * PI).sqrt()


def as_cdf(x):
    ax = abs(x)
    k = 1 / (1 + AS_P * ax)
    poly = Decimal(0)
    for b in reversed(AS_B):
        poly = (poly + b) * k
    upper = INV_SQRT_2PI * (-(ax * ax) / 2).exp() * poly
    return 1 - upper if x >= 0 else upper


A = [Decimal(s) for s in (
    "3.3871328727963666080e0", "1.3314166789178437745e+2",
    "1.9715909503065514427e+3", "1.3731693765509461125e+4",
    "4.5921953931549871457e+4", "6.7265770927008700853e+4",
    "3.3430575583588128105e+4", "2.5090809287301226727e+3")]
B = [Decimal(s) for s in (
    "1", "4.2313330701600911252e+1", "6.8718700749205790830e+2",
    "5.3941960214247511077e+3", "2.1213794301586595867e+4",
    "3.9307895800092710610e+4", "2.8729085735721942674e+4",
    "5.2264952788528545610e+3")]
C = [Decimal(s) for s in (
    "1.42343711074968357734e0", "4.63033784615654529590e0",
    "5.76949722146069140550e0", "3.64784832476320460504e0",
    "1.27045825245236838258e0", "2.41780725177450611770e-1",
    "2.27238449892691845833e-2", "7.74545014278341407640e-4")]
D = [Decimal(s) for s in (
    "1", "2.05319162663775882187e0", "1.67638483018380384940e0",
    "6.89767334985100004550e-1", "1.48103976427480074590e-1",
    "1.51986665636164571966e-2", "5.47593808499534494600e-4",
    "1.05075007164441684324e-9")]
E = [Decimal(s) for s in (
    "6.65790464350110377720e0", "5.46378491116411436990e0",
    "1.78482653991729133580e0", "2.96560571828504891230e-1",
    "2.65321895265761230930e-2", "1.24266094738807843860e-3",
    "2.71155556874348757815e-5", "2.01033439929228813265e-7")]
F = [Decimal(s) for s in (
    "1", "5.99832206555887937690e-1", "1.36929880922735805310e-1",
    "1.48753612908506148525e-2", "7.86869131145613259100e-4",
    "1.84631831751005468180e-5", "1.42151175831644588870e-7",
    "2.04426310338993978564e-15")]


def poly(coeffs, r):
    total = Decimal(0)
    for c in reversed(coeffs):
        total = total * r + c
    return total


def as241(p):
    q = p - Decimal("0.5")
    if abs(q) <= Decimal("0.425"):
        r = Decimal("0.180625") - q * q
        return q * poly(A, r) / poly(B, r)
    r = min(p, 1 - p)
    r = (-r.ln()).sqrt()
    if r <= 5:
        r -= Decimal("1.6")
        x = poly(C, r) / poly(D, r)
    else:
        r -= 5
        x = poly(E, r) / poly(F, r)
    return -x if q < 0 else x


def lines(rng):
    out = []
    for raw in rng.integers(0, VAL_BOUND, COUNT, endpoint=True):
        raw = int(raw)
        root = math.isqrt(raw * ONE)
        if (2 * root + 1) ** 2 <= 4 * raw * ONE:
            root += 1
        out.append(f"sqrt {raw} {root} {root}")
    exp_max = (47 * ONE) // 4
    for raw in rng.integers(-30 * ONE, exp_max, COUNT, endpoint=True):
        raw = int(raw)
        want = to_raw(as_decimal(raw).exp())
        out.append(f"exp {raw} {want} {want}")
    for e in rng.uniform(0.0, 57.0, COUNT):
        raw = max(1, int(2.0**e))
        want = to_raw(as_decimal(raw).ln())
        out.append(f"log {raw} {want} {want}")
    for raw in rng.integers(-9 * ONE, 9 * ONE, COUNT, endpoint=True):
        raw = int(raw)
        x = as_decimal(raw)
        true = to_raw(Decimal(float(special.ndtr(float(x)))))
        out.append(f"cdf {raw} {to_raw(as_cdf(x))} {true}")
    probabilities = [int(v) for v in rng.integers(1, ONE - 1, COUNT)]
    probabilities += [1, 2, 1000, ONE // 2, ONE - 1000, ONE - 1]
    probabilities += [int(ONE * 10.0**-k) for k in range(2, 12)]
    for raw in probabilities:
        p = as_decimal(raw)
        true = to_raw(Decimal(float(special.ndtri(float(p)))))
        out.append(f"inv {raw} {to_raw(as241(p))} {true}")
    return out


def main(path):
    rng = np.random.default_rng(SEED)
    body = lines(rng)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        f"{len(body)} lines: function input definition true "
        f"(raw at Frac {FRAC}; tools/make_elementary.py, seed {SEED})\n"
        + "\n".join(body) + "\n")


if __name__ == "__main__":
    main(Path(sys.argv[1]))
