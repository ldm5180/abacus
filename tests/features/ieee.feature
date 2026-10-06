Feature: IEEE-754 bit patterns

  A data file may hold numbers as binary64 or binary32 bit patterns.
  Their sign, exponent and fraction are taken apart as integers, never
  reinterpreted as a float, and the number reads as the value on the
  grid nearest to it.  Not-a-number and the infinities are refused by
  name, and so is a number past the values; zero, signed or not, and
  the subnormals are numbers like any other.

  Scenario: The bits of -120.0 read as -120
    When the binary64 bits C05E000000000000 are read
    Then the bits read as -120 over 1

  Scenario: A number the grid cannot hold reads as the value nearest it
    When the binary64 bits 3FB999999999999A are read
    Then the bits read as 109951162778 units

  Scenario Outline: Zero, signed or not, and the subnormals read as zero
    When the binary64 bits <bits> are read
    Then the bits read as 0 units

    Examples:
      | bits             | number            |
      | 0000000000000000 | zero              |
      | 8000000000000000 | negative zero     |
      | 0000000000000001 | least subnormal   |
      | 800FFFFFFFFFFFFF | largest, negative |

  Scenario Outline: Not-a-number and the infinities are refused by name
    When the binary64 bits <bits> are read
    Then the bits are refused as <reason>

    Examples:
      | bits             | reason       |
      | 7FF8000000000000 | not a number |
      | FFF0000000000001 | not a number |
      | 7FF0000000000000 | infinite     |
      | FFF0000000000000 | infinite     |
      | 7E37E43C8800759C | out of range |
      | 4100000000000001 | out of range |

  Scenario: The largest value reads, and one step past it does not
    When the binary64 bits 4100000000000000 are read
    Then the bits read as 131072 over 1
    When the binary64 bits 4100000000000001 are read
    Then the bits are refused as out of range

  Scenario: A binary32 pattern reads by the same rules
    When the binary32 bits 3F000000 are read
    Then the bits read as 1 over 2
    When the binary32 bits 7FC00000 are read
    Then the bits are refused as not a number
