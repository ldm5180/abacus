Feature: Arithmetic on the grid

  A value is a whole number of units of 2 to the power -40, held in 64
  bits.  A product is formed in 128 bits and rounded once, to nearest
  with ties away from zero; a result too large for a value is reported,
  never wrapped.

  Scenario: One is two to the fortieth units
    Then one is 1099511627776 units
