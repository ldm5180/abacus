Feature: Decimal text

  A number in a file or a configuration is decimal text.  It reads as
  the value on the grid nearest to it, exactly, with no float between,
  and a value writes back as the shortest text that reads as it again.
  Text that is not a number is refused, and the refusal says why.

  Scenario: 0.2621 reads and writes back as 0.2621
    When the text "0.2621" is read
    Then the text writes back as "0.2621"

  Scenario: A number reads as the value nearest to it
    When the text "0.25" is read
    Then the text reads as 1 over 4
    When the text "-2.5e-1" is read
    Then the text reads as -1 over 4
    When the text "1e-13" is read
    Then the text reads as 0 units

  Scenario Outline: Half a unit rounds away from zero, and less than half toward it
    When the text "<text>" is read
    Then the text reads as <units> units

    Examples:
      | text                                         | units |
      | 0.00000000000045474735088646411895751953125  | 1     |
      | -0.00000000000045474735088646411895751953125 | -1    |
      | 0.00000000000045474735088646411895751953124  | 0     |

  Scenario: A value writes back as the fewest places that read as it
    When the text "0.333333333333333333333333" is read
    Then the text writes back as "0.333333333333"
    And written to 4 places it is "0.3333"
    And written to 0 places it is "0"

  Scenario: Rounding to fewer places carries into the whole part
    When the text "0.9999999" is read
    Then written to 2 places it is "1.00"

  Scenario Outline: Text that is not a number is refused, and says why
    When the text "<text>" is read
    Then the text is refused as <reason>

    Examples:
      | text   | reason       |
      | 1.2.3  | unexpected   |
      | 12abc  | unexpected   |
      | -      | incomplete   |
      | 1e     | incomplete   |
      | 131073 | out of range |
      | 2e9    | out of range |

  Scenario: An unexpected character is named by its place
    When the text "1.2.3" is read
    Then the text is refused as unexpected
    And the refusal is at position 4

  Scenario: An empty text is refused as empty
    When an empty text is read
    Then the text is refused as empty
