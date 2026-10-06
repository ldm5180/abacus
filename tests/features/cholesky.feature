Feature: Cholesky factorization

  A symmetric matrix factors as L L' when every pivot clears a floor the
  caller sets; the factor then solves a system by two triangular
  solves.  A matrix that does not factor is refused, and the column at
  which it failed is named, because a tiny pivot is not a number to go
  on with.  On this grid a singular matrix's pivot is not zero but the
  root of the rounding it carries, about 1e-6, so a floor sits above
  that.

  Scenario: A matrix with a repeated column is refused, and the column is named
    Given the matrix of observations:
      | 1 | 2 | 2 |
      | 2 | 1 | 1 |
      | 3 | 0 | 0 |
      | 4 | 1 | 1 |
    When its Gram matrix is factored with a floor of 0.0001
    Then the factorization is refused at column 3

  Scenario: A symmetric matrix factors, and its factor solves a system
    Given the symmetric matrix:
      | 4 | 2 |
      | 2 | 3 |
    When it is factored with a floor of 0.000001
    Then it factors
    When it is solved for 8, 7
    Then the solution is within 0.000000000002 of 1.25, 1.5

  Scenario: A matrix that is not positive definite is refused at its column
    Given the symmetric matrix:
      | 1 | 2 |
      | 2 | 1 |
    When it is factored with a floor of 0.000001
    Then the factorization is refused at column 2

  Scenario: A line fitted by least squares
    Given the matrix of observations:
      | 1 | 0 |
      | 1 | 1 |
      | 1 | 2 |
      | 1 | 3 |
    When the column 1, 3, 5, 7 is fitted by least squares with a ridge of 0
    Then the solution is within 0.000000000004 of 1, 2
