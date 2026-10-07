Feature: Scrambled Sobol sequences

  Points in the unit cube in up to 64 dimensions, each coordinate an
  integer over 2**32, made from Joe and Kuo's direction numbers in
  Gray-code order.  Scrambled from a seed -- a random linear matrix
  scramble and a random digital shift, scipy's method with abacus's own
  generator -- they stay as evenly spread: a block of 2**k points drawn
  at a multiple of its size puts exactly one point in each of 2**k equal
  intervals of every coordinate.

  Scenario: The first points are the published ones
    Given a Sobol sequence in 3 dimensions
    When 8 points are drawn
    Then coordinate 1 runs 0, 0.5, 0.75, 0.25, 0.375, 0.875, 0.625, 0.125
    And coordinate 2 runs 0, 0.5, 0.25, 0.75, 0.375, 0.875, 0.125, 0.625
    And coordinate 3 runs 0, 0.5, 0.25, 0.75, 0.625, 0.125, 0.875, 0.375

  Scenario: A scrambled block of 1,024 points puts one in each of 1,024 equal intervals
    Given a Sobol sequence in 6 dimensions scrambled with the seed 42
    When a block of 1024 points is drawn
    Then every coordinate has one point in each of 1024 equal intervals

  Scenario: The block after it is stratified too
    Given a Sobol sequence in 6 dimensions scrambled with the seed 42
    When a block of 256 points is drawn
    And a block of 256 points is drawn
    Then every coordinate has one point in each of 256 equal intervals

  Scenario: One seed gives one stream, and another seed another
    Given a Sobol sequence in 4 dimensions scrambled with the seed 7
    When 100 points are drawn
    Then the seed 7 gives the same 100 points again
    And the seed 8 gives a different point at every one of them

  Scenario: A block that does not start at a multiple of its size is refused
    Given a Sobol sequence in 2 dimensions scrambled with the seed 7
    When 3 points are drawn
    And a block of 8 points is drawn
    Then the block is refused as misaligned
