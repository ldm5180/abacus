Feature: Quadratic programs

  Minimize (1/2) x'P x + q'x subject to lo <= x <= hi and
  row_lo <= E x <= row_hi.  The answer is certified: its primal and
  dual residuals and its complementarity are computed at 128 bits and
  each held within its tolerance.  Every hundred iterations the problem
  is solved exactly with the bounds the iterate holds -- the polish --
  and that answer is kept when it is certified; a linear program is
  instead crossed over from the bounds the iterate holds to a vertex, by
  pivots.  Each row's step suits
  the row's own scale, so a program with a column far larger than the
  rest is solved as readily as one in balance.  A problem that cannot be met is
  refused as infeasible, one whose objective falls without end as
  unbounded, and one whose matrix is not positive semidefinite as not
  convex.  A run of rows may instead lie in a second-order cone,
  ||u|| <= s, which makes the problem a second-order cone program: the
  answer is then also held to how far its rows lie outside the cone and
  its multipliers outside the cone's polar.

  Scenario: A budget is split between two equal parts
    Given a problem in 2 variables with the identity as its matrix
    And both variables between 0 and 1
    And the variables summing to exactly 1
    When it is solved
    Then the answer is certified
    And each variable is 0.5

  Scenario: Bounds that cannot be met are refused
    Given a problem in 2 variables with the identity as its matrix
    And both variables between 0 and 0.25
    And the variables summing to exactly 1
    When it is solved
    Then the outcome is infeasible

  Scenario: A cap that binds holds its variable at the cap
    Given a problem in 2 variables with the identity as its matrix
    And both variables between 0 and 1
    And variable 1 at most 0.75
    And the linear objective -1, 0
    And the variables summing to exactly 1
    When it is solved
    Then the answer is certified
    And variable 1 is 0.75
    And variable 2 is 0.25

  Scenario: An at-most budget binds only when it is reached
    Given a problem in 2 variables with the identity as its matrix
    And both variables between 0 and 1
    And the linear objective -1, -1
    And the variables summing to at most 0.5
    When it is solved
    Then the answer is certified
    And each variable is 0.25

  Scenario: A linear program is the case of no quadratic term
    Given a problem in 2 variables with no quadratic term
    And both variables between 0 and 1
    And the linear objective -1, -2
    And the variables summing to at most 1.5
    When it is solved
    Then the answer is certified
    And variable 1 is 0.5
    And variable 2 is 1

  Scenario: An objective that falls without end is refused as unbounded
    Given a problem in 2 variables with no quadratic term
    And both variables between 0 and 1
    And variable 1 with no upper bound
    And the linear objective -1, 0
    When it is solved
    Then the outcome is unbounded

  Scenario: A matrix that is not positive semidefinite is refused as not convex
    Given a problem in 2 variables with the diagonal 1, -1 as its matrix
    And both variables between 0 and 1
    When it is solved
    Then the outcome is not convex

  Scenario: A warm start from a near answer takes fewer iterations
    Given a problem in 2 variables with the identity as its matrix
    And both variables between 0 and 1
    And the linear objective -0.1, 0
    And the variables summing to exactly 1
    When it is solved
    And it is solved again from that answer with the linear objective -0.125, 0
    Then the answer is certified
    And it took fewer iterations than a cold start does

  Scenario: An answer holding dozens of variables, with caps and two budgets, agrees with OSQP's
    Given the spread problem from the fixtures
    When it is solved
    Then the answer is certified
    And at least 40 variables are above zero
    And the answer agrees with the oracle's within 0.000001

  Scenario: A ratio program posed homogenized, one column ten times the root of n where the rest are near one, agrees with its exact answer
    Given the ratio problem from the fixtures
    When it is solved
    Then the answer is certified
    And the answer agrees with the oracle's within 0.000000001

  Scenario: A tail-mean program whose outcomes tie, its vertex near-degenerate, is crossed over to it
    Given the ticked problem from the fixtures
    When it is solved
    Then the answer is certified
    And the answer agrees with the oracle's within 0.000000001

  Scenario: A large problem that cannot be met is refused as infeasible
    Given the infeasible problem from the fixtures
    When it is solved
    Then the outcome is infeasible

  Scenario: A large matrix that is not positive semidefinite is refused as not convex
    Given the nonconvex problem from the fixtures
    When it is solved
    Then the outcome is not convex

  Scenario: A tail-mean linear program, its bounds boxed by its data, is certified by the polish
    Given the tail_bounded problem from the fixtures
    When it is solved
    Then the answer is certified
    And the answer agrees with the oracle's within 0.000001

  Scenario: The same program with its threshold and shortfalls unbounded is certified too
    Given the tail problem from the fixtures
    When it is solved
    Then the answer is certified
    And the answer agrees with the oracle's within 0.000001

  Scenario: An answer the solver cannot certify is reported so, never as certified
    Given the tail problem from the fixtures
    When it is solved without the polish
    Then the outcome is exhausted

  Scenario: A linear objective over a disc puts the answer on its edge
    Given a problem in 2 variables with no quadratic term
    And the linear objective -1, -1
    And the variables within a disc of radius 1
    When it is solved
    Then the answer is certified
    And each variable is 0.707106781

  Scenario: The deviation of 1,500 outcomes over 14 columns, held by a cone, agrees with the conic solvers
    Given the deviation problem from the fixtures
    When it is solved
    Then the answer is certified
    And the answer agrees with the oracle's within 0.000001
