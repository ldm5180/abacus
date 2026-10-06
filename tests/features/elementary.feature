Feature: Elementary functions

  Square root, exp, log, the normal distribution and its quantile, each
  checked against its own definition at the grid's resolution.  A root
  is the nearest value to the true one; exp and log are within a unit
  of it; the normal CDF carries Abramowitz and Stegun's error, under
  7.5e-8, and its inverse Wichura's.  An argument is first read to the
  grid, and a steep function magnifies that rounding: the quantile's
  slope near 0.975 is 17.

  Scenario: The square root of 2, squared, is 2 to the grid
    When the root of 2 is taken
    Then its square is 2 within 2 units

  Scenario: Exp and log undo each other
    When the log of 3 is taken
    And the exp of the result is taken
    Then the result is 3 within 0.000000000004

  Scenario: The exp of one is e
    When the exp of 1 is taken
    Then the result is 2.718281828459045 within 0.000000000002

  Scenario Outline: The normal CDF at familiar points, within its stated error
    When the cdf of <x> is taken
    Then the result is <p> within 0.000000075

    Examples:
      | x                  | p                  |
      | 0                  | 0.5                |
      | 1                  | 0.8413447460685429 |
      | 1.959963984540054  | 0.975              |
      | -1.644853626951473 | 0.05               |
      | 9                  | 1                  |

  Scenario: The quantile undoes the CDF, to the grid its argument is on
    When the quantile of 0.975 is taken
    Then the result is 1.959963984540054 within 0.00000000001
    When the cdf of the result is taken
    Then the result is 0.975 within 0.000000075

  Scenario: A quantile far into the tail, of a probability the grid holds
    When the quantile of 0.000000000931322574615478515625 is taken
    Then the result is -6.009353565530744 within 0.000000000003
