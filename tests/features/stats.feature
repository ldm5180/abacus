Feature: Statistics

  Quantiles, means, variances and covariances on tables small enough to
  check by hand.  Every sum is exact, so the order of the data does not
  matter, and a window that slides keeps sums equal to a fresh window's
  bit for bit.

  Scenario: The median of 1, 2, 3, 4 by the nearest rule is 3
    Given the data 1, 2, 3, 4
    When the 0.5 quantile is taken by the nearest rule
    Then the answer is 3

  Scenario: The linear rule draws the line between neighbours
    Given the data 1, 2, 3, 4
    When the 0.5 quantile is taken by the linear rule
    Then the answer is 2.5
    When the 0.25 quantile is taken by the linear rule
    Then the answer is 1.75

  Scenario: The order the data arrive in does not change a quantile
    Given the data 4, -2.5, 3, 0.125, 3
    When the 0.75 quantile is taken by the nearest rule
    Then the answer is 3
    Given the data 3, 3, 0.125, -2.5, 4
    When the 0.75 quantile is taken by the nearest rule
    Then the answer is 3
    When the 0 quantile is taken by the nearest rule
    Then the answer is -2.5
