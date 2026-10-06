Feature: Statistics

  Quantiles, means, variances and covariances on tables small enough to
  check by hand.  Every sum is exact, so the order of the data does not
  matter, and a window that slides keeps sums equal to a fresh window's
  bit for bit.

  Scenario: The median of 1, 2, 3, 4 by the nearest rule is 3
    Given the data 1, 2, 3, 4
    When the 0.5 quantile is taken by the nearest rule
    Then the statistic is 3

  Scenario: The linear rule draws the line between neighbours
    Given the data 1, 2, 3, 4
    When the 0.5 quantile is taken by the linear rule
    Then the statistic is 2.5
    When the 0.25 quantile is taken by the linear rule
    Then the statistic is 1.75

  Scenario: The order the data arrive in does not change a quantile
    Given the data 4, -2.5, 3, 0.125, 3
    When the 0.75 quantile is taken by the nearest rule
    Then the statistic is 3
    Given the data 3, 3, 0.125, -2.5, 4
    When the 0.75 quantile is taken by the nearest rule
    Then the statistic is 3
    When the 0 quantile is taken by the nearest rule
    Then the statistic is -2.5

  Scenario: The mean and the variance of a table checked by hand
    Given the data 2, 4, 4, 4, 5, 5, 7, 9
    When the mean is computed
    Then the statistic is 5
    When the population variance is computed
    Then the statistic is 4
    When the sample variance is computed
    Then the statistic is within 0.000000000002 of 4.571428571428571
    When the population standard deviation is computed
    Then the statistic is 2

  Scenario: A weighted mean counts each value by its weight
    Given the data 2, 4, 4, 4, 5, 5, 7, 9
    And the weights 1, 1, 1, 1, 2, 2, 0, 0
    When the weighted mean is computed
    Then the statistic is 4.25

  Scenario: Covariance and correlation of two series
    Given the data 2, 4, 4, 4, 5, 5, 7, 9
    And the second series 1, 3, 2, 5, 4, 6, 8, 7
    When the population covariance is computed
    Then the statistic is 3.875
    When the correlation is computed
    Then the statistic is within 0.000000000005 of 0.8455943246644705

  Scenario: A slid window equals a fresh one
    Given a window over 3 series
    And the rows 0.01, 0.02, -0.03 and 0.015, -0.005, 0.0 and -0.02, 0.01, 0.04
    When the row 0.03, 0.0, -0.01 is added
    And the oldest row is removed
    Then the window's sums equal a fresh window's over its rows
    And the sample covariance of series 1 and 3 is the fresh one's
