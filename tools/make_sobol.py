"""Write Abacus.Sobol's direction-number table and its test fixture.

The direction numbers are Joe and Kuo's, criterion D(6), from the file
new-joe-kuo-6.21201 they publish (sha256 68eedd2a4e3b659b9695e7aff0f8ac
68718bcf620730fc3d3a8c65df2a067441).  Its first 64 lines -- the header
and dimensions 2 to 64; dimension 1 has no line, its numbers are all
one -- are kept in tools/sobol/new-joe-kuo-6.64, cut with `head -64`,
with the licence they are published under in tools/sobol/LICENCE.  They
are checked here against the copy scipy ships (its primitive
polynomials and initial numbers), when scipy is at hand.

Written:

* src/abacus-sobol-directions.ads -- per dimension, the degree s of the
  primitive polynomial, the number a coding its inner coefficients, and
  the initial direction numbers m_1 .. m_s.
* tests/data/sobol.txt -- the first 64 unscrambled points in 64
  dimensions as scipy's qmc.Sobol (scramble=False, bits=32) gives them;
  the first 256 scrambled points in 8 dimensions for the seed 20261006,
  from a second implementation of Abacus.Sobol's scramble written here
  (its seed stream is abacus's, so scipy cannot give these); scipy's
  L2-star discrepancy of those 256 points; and, for comparison, the mean
  and the largest of the same discrepancy over scipy's own scrambled
  Sobol points for 64 seeds, and the mean over 64 seeds of uniform
  pseudo-random points.  Discrepancies are raw at Frac 40.

Python runs only to write these files.  Usage, from the repository root:

    python tools/make_sobol.py
"""

import os
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
EXCERPT = ROOT / "tools" / "sobol" / "new-joe-kuo-6.64"
TABLE = ROOT / "src" / "abacus-sobol-directions.ads"
FIXTURE = ROOT / "tests" / "data" / "sobol.txt"

DIMENSIONS = 64
BITS = 32
MASK = 2**BITS - 1
MASK64 = 2**64 - 1
FRAC = 40
SEED = 20261006
SCRAMBLED_D, SCRAMBLED_N = 8, 256
UNSCRAMBLED_D, UNSCRAMBLED_N = 64, 64
COMPARISONS = 64


def read_excerpt():
    """Dimension -> (s, a, m) for dimensions 2 .. 64."""
    table = {}
    for line in EXCERPT.read_text().splitlines()[1:]:
        d, s, a, *m = (int(x) for x in line.split())
        assert len(m) == s
        table[d] = (s, a, m)
    assert sorted(table) == list(range(2, DIMENSIONS + 1))
    return table


def check_against_scipy(table):
    try:
        import scipy.stats
    except ImportError:
        return "scipy not at hand: not checked"
    path = os.path.join(os.path.dirname(scipy.stats.__file__),
                        "_sobol_direction_numbers.npz")
    data = np.load(path)
    for d, (s, a, m) in table.items():
        assert data["poly"][d - 1] == (1 << s) | (a << 1) | 1, d
        assert list(data["vinit"][d - 1][:s]) == m, d
    return "agrees with scipy's copy for every dimension"


def directions(table, d):
    """The 32 direction numbers of dimension d, left-aligned."""
    if d == 1:
        return [1 << (BITS - k) for k in range(1, BITS + 1)]
    s, a, m = table[d]
    v = [m[k - 1] << (BITS - k) for k in range(1, s + 1)]
    for k in range(s + 1, BITS + 1):
        x = v[k - s - 1] ^ (v[k - s - 1] >> s)
        for i in range(1, s):
            if (a >> (s - 1 - i)) & 1:
                x ^= v[k - i - 1]
        v.append(x)
    return v


class SplitMix64:
    """Abacus.Random's generator."""

    def __init__(self, seed):
        self.state = seed & MASK64

    def next(self):
        self.state = (self.state + 0x9E3779B97F4A7C15) & MASK64
        z = self.state
        z = ((z ^ (z >> 30)) * 0xBF58476D1CE4E5B9) & MASK64
        z = ((z ^ (z >> 27)) * 0x94D049BB133111EB) & MASK64
        return z ^ (z >> 31)


def parity(x):
    return bin(x).count("1") & 1


def scramble(table, d, seed):
    """Abacus.Sobol.Scrambled's shift and scrambled direction numbers."""
    g = SplitMix64(seed)
    shifts, vs = [], []
    for j in range(1, d + 1):
        shifts.append(g.next() & MASK)
        masks = []
        for p in range(BITS - 1):
            above = MASK ^ ((1 << (p + 1)) - 1)
            masks.append(((g.next() & MASK) & above) | (1 << p))
        masks.append(1 << (BITS - 1))
        vs.append([sum(parity(masks[p] & v) << p for p in range(BITS))
                   for v in directions(table, j)])
    return shifts, vs


def points(shifts, vs, n):
    """The first n points in Gray-code order."""
    x = list(shifts)
    out = []
    for i in range(n):
        out.append(list(x))
        c = 0
        while (i >> c) & 1:
            c += 1
        for j in range(len(x)):
            x[j] ^= vs[j][c]
    return out


def wrapped(items, indent="      ", width=79):
    """Items separated by commas, in lines of at most width columns."""
    lines, line = [], indent
    for item in items:
        if len(line) + len(item) + 2 > width and line.strip():
            lines.append(line.rstrip())
            line = indent
        line += item + ", "
    lines.append(line.rstrip().rstrip(","))
    return "\n".join(lines).lstrip()


def write_table(table):
    listed = range(2, DIMENSIONS + 1)
    degree = wrapped([str(table[d][0]) for d in listed])
    coded = wrapped([str(table[d][1]) for d in listed])
    rows = ",\n".join(f"      {d} => [" + ", ".join(
        str(x) for x in table[d][2] + [0] * (9 - table[d][0])) + "]"
        for d in listed).lstrip()
    text = f"""\
--  Generated by tools/make_sobol.py from the first 64 lines of Joe and
--  Kuo's new-joe-kuo-6.21201 (tools/sobol/new-joe-kuo-6.64); do not edit.
--  The direction numbers are published under the licence in
--  tools/sobol/LICENCE, whose notice is:
--  Copyright (c) 2008, Frances Y. Kuo and Stephen Joe.  All rights
--  reserved.

--  The primitive polynomials and initial direction numbers of dimensions
--  2 to 64.  Dimension 1 has none: its direction numbers are all one.

private package Abacus.Sobol.Directions
  with SPARK_Mode, Pure
is

   subtype Listed is Dimension range 2 .. Max_Dimension;

   --  The highest degree of a listed polynomial.
   Max_Degree : constant := 9;

   subtype Degree_Value is Positive range 1 .. Max_Degree;

   --!format off
   --  The degree s of each dimension's primitive polynomial.
   Degree : constant array (Listed) of Degree_Value :=
     [{degree}];

   --  The polynomial's inner coefficients a_1 .. a_(s-1), as the bits of
   --  a number, a_1 the highest.
   Coded : constant array (Listed) of Natural :=
     [{coded}];

   --  The initial direction numbers m_1 .. m_s, each odd and below 2**k,
   --  padded with zeros.
   Initial : constant array (Listed, Degree_Value) of Natural :=
     [{rows}];
   --!format on

end Abacus.Sobol.Directions;
"""
    TABLE.write_text(text)


def l2_star(x):
    return float(__import__("scipy.stats", fromlist=["qmc"]).qmc.discrepancy(
        x, method="L2-star"))


def write_fixture(table):
    from scipy.stats import qmc
    plain = qmc.Sobol(UNSCRAMBLED_D, scramble=False, bits=BITS)
    unscrambled = np.round(plain.random_base2(6) * 2.0**BITS).astype(np.int64)
    ours = points(*scramble(table, SCRAMBLED_D, SEED), SCRAMBLED_N)
    ours_unit = np.array(ours, dtype=float) / 2.0**BITS
    theirs = [l2_star(qmc.Sobol(SCRAMBLED_D, scramble=True, seed=s)
                      .random_base2(8)) for s in range(COMPARISONS)]
    rng = np.random.default_rng(SEED)
    uniform = [l2_star(rng.random((SCRAMBLED_N, SCRAMBLED_D)))
               for _ in range(COMPARISONS)]
    ours_d = l2_star(ours_unit)
    raw = lambda v: str(round(v * 2.0**FRAC))
    lines = [
        "abacus Sobol fixture (written by tools/make_sobol.py): the first"
        f" {UNSCRAMBLED_N} unscrambled points in {UNSCRAMBLED_D} dimensions"
        " (scipy), one per line, each coordinate times 2**32",
        *[" ".join(map(str, row)) for row in unscrambled],
        f"the first {SCRAMBLED_N} scrambled points in {SCRAMBLED_D}"
        f" dimensions for the seed {SEED}, by this script's second"
        " implementation of the scramble",
        *[" ".join(map(str, row)) for row in ours],
        "L2-star discrepancies, raw at Frac 40: scipy's of the points above;"
        f" the mean and the largest of scipy's own scrambled Sobol over"
        f" {COMPARISONS} seeds; the mean of uniform pseudo-random points over"
        f" {COMPARISONS} seeds",
        " ".join([raw(ours_d), raw(np.mean(theirs)), raw(max(theirs)),
                  raw(np.mean(uniform))]),
        f"readable: ours {ours_d:.6e}; scipy's scrambled mean"
        f" {np.mean(theirs):.6e}, largest {max(theirs):.6e}; uniform mean"
        f" {np.mean(uniform):.6e}",
    ]
    FIXTURE.write_text("\n".join(lines) + "\n")
    return lines[-1]


def main():
    table = read_excerpt()
    print("direction numbers:", check_against_scipy(table))
    write_table(table)
    print(write_fixture(table))


if __name__ == "__main__":
    main()
