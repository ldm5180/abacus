Feature: Decimal text

  A number in a file or a configuration is decimal text.  It reads as
  the value on the grid nearest to it, exactly, with no float between,
  and a value writes back as the shortest text that reads as it again.
  Text that is not a number is refused, and the refusal says why.

  Scenario: 0.2621 reads and writes back as 0.2621
    When the text "0.2621" is read
    Then the text writes back as "0.2621"
