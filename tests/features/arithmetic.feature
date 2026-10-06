Feature: Arithmetic on the grid

  A value is a whole number of units of 2 to the power -40, held in 64
  bits.  A product or a quotient is formed in 128 bits and rounded once,
  to nearest with ties away from zero.  A result too large for a value
  is held at the largest value of its sign and reported, never wrapped,
  and a quotient by zero is undefined rather than infinite.

  Scenario: One is two to the fortieth units
    Then the value one is 1099511627776 units

  Scenario: A half times a half is a quarter
    Given a is 1 over 2
    And b is 1 over 2
    When a is multiplied by b
    Then the result is 1 over 4

  Scenario Outline: A product halfway between two units rounds away from zero
    Given a is <units> units
    And b is 1 over 2
    When a is multiplied by b
    Then the result is <rounded> units

    Examples:
      | units | rounded |
      | 3     | 2       |
      | -3    | -2      |
      | 1     | 1       |
      | -1    | -1      |
      | 4     | 2       |

  Scenario: A quotient is the unit nearest to it
    Given a is 1
    And b is 3
    When a is divided by b
    Then the result is 366503875925 units
    And the result is 1 over 3

  Scenario: The order of a product does not matter
    Given a is 2 over 3
    And b is -5 over 7
    When a is multiplied by b
    Then the result is -523576965608 units
    When b is multiplied by a
    Then the result is -523576965608 units

  Scenario: A product too large is reported, not wrapped
    Given a is 100000
    And b is 100000
    When a is multiplied by b
    Then the result is saturated
    And the result is the largest value

  Scenario: A product too far below zero is held at the smallest value
    Given a is 100000
    And b is -100000
    When a is multiplied by b
    Then the result is saturated
    And the result is the smallest value

  Scenario: A quotient by zero is undefined
    Given a is 1
    And b is 0
    When a is divided by b
    Then the result is undefined
