# Covers functionalities in ./pos_scanner.go
# Derived from tests in ./pos_scanner_test.go

Feature: HCL Range Scanner
  This feature tests the `RangeScanner` which is used to scan byte slices
  (representing HCL source code) using a provided `bufio.SplitFunc` (typically line by line).
  It tracks the source position (byte, line, column) and provides the bytes
  for each scanned token.

  Scenario Outline: Scanning input with various line endings and content using ScanLines
    Given an input string: <input_string>
    When `NewRangeScanner` is initialized with this input, filename "", and `bufio.ScanLines`
    And the scanner is iterated until `Scan()` returns false
    Then no scanner errors should occur
    And the sequence of scanned line contents (bytes) should be: <expected_lines_content>
    And the sequence of HCL Ranges for each scanned line should be: <expected_ranges>

    Examples:
      | input_string                        | expected_lines_content        | expected_ranges                                                                 |
      | `""`                                | `[]`                          | `[]`                                                                            | # empty
      | `"hello"`                           | `["hello"]`                   | `[L1C1(B0)-L1C6(B5)]`                                                           | # single line
      | `"hello\\n"`                        | `["hello"]`                   | `[L1C1(B0)-L1C6(B5)]`                                                           | # single line with trailing UNIX newline
      | `"hello\\r\\n"`                     | `["hello"]`                   | `[L1C1(B0)-L1C6(B5)]`                                                           | # single line with trailing Windows newline
      | `"hello\\nworld"`                   | `["hello", "world"]`          | `[L1C1(B0)-L1C6(B5), L2C1(B6)-L2C6(B11)]`                                        | # two lines with UNIX newline
      | `"hello\\r\\nworld"`                | `["hello", "world"]`          | `[L1C1(B0)-L1C6(B5), L2C1(B7)-L2C6(B12)]`                                        | # two lines with Windows newline
      | `"hello\\n\\nworld"`                | `["hello", "", "world"]`      | `[L1C1(B0)-L1C6(B5), L2C1(B6)-L2C1(B6), L3C1(B7)-L3C6(B12)]`                     | # blank line with UNIX newlines
      | `"hello\\r\\n\\r\\nworld"`          | `["hello", "", "world"]`      | `[L1C1(B0)-L1C6(B5), L2C1(B7)-L2C1(B7), L3C1(B9)-L3C6(B14)]`                     | # blank line with Windows newlines
      | `"foo \\U0001f469\\U0001f3ff bar\\nbaz"` | `["foo 👩🏿 bar", "baz"]`   | `[L1C1(B0)-L1C10(B16), L2C1(B17)-L2C4(B20)]`                                     | # two lines with combiner and UNIX newline
      | `"foo \\U0001f469\\U0001f3ff bar\\r\\nbaz"`| `["foo 👩🏿 bar", "baz"]` | `[L1C1(B0)-L1C10(B16), L2C1(B18)-L2C4(B21)]`                                     | # two lines with combiner and Windows newline

  Scenario: Scanning a fragment with a starting offset
    Given an input string:
      """
      line one
      line two
      line three
      """
    And a starting position: Line 5, Column 10, Byte 50
    When `NewRangeScannerFragment` is initialized with the input string, filename "frag.hcl", the starting position, and `bufio.ScanLines`
    And the scanner is iterated
    Then the HCL Range for the first scanned line ("line one") should be Start:L5C10(B50)-End:L5C18(B58)
    And the HCL Range for the second scanned line ("line two") should be Start:L6C1(B59)-End:L6C9(B67)
    And the HCL Range for the third scanned line ("line three") should be Start:L7C1(B68)-End:L7C11(B78)
    And no scanner errors should occur

  Scenario: Error propagation from custom SplitFunc
    Given an input string "first line\nerror here"
    And a custom SplitFunc that returns "first line" then an error "custom split error" on the second call
    When `NewRangeScanner` is initialized with the input string, filename "error.hcl", and the custom SplitFunc
    And the scanner's `Scan()` method is called until it returns false
    Then the scanner's `Err()` method should return an error
    And the error message should be "custom split error"
    And the first scanned line content should be "first line"
    And its range should be L1C1(B0)-L1C11(B10)

    # Notes for table values:
    # - Input strings are Go-escaped for newlines and unicode.
    # - `expected_lines_content`: A list of strings representing the byte content of each line.
    #   Unicode characters like 👩🏿 are represented directly.
    # - `expected_ranges`: A list of HCL Range strings, e.g., `L1C1(B0)-L1C6(B5)` means
    #   Start: Line 1, Column 1, Byte 0 and End: Line 1, Column 6, Byte 5.
    # - The byte offsets in ranges account for the width of newline characters (`\n` is 1 byte, `\r\n` is 2 bytes)
    #   and multi-byte UTF-8 characters. Column counts are based on Unicode characters.
    # - For the fragment scenario, byte offsets for subsequent lines are calculated based on the preceding line's content and newline char.
    #   e.g., "line one" (8 bytes) + \n (1 byte) = 9 bytes. So next line starts at Byte 50+9 = 59.
    #   "line two" (8 bytes) + \n (1 byte) = 9 bytes. So next line starts at Byte 59+9 = 68.
    #   "line three" (10 bytes). End Byte is 68+10=78.
    #   Column for "line one" end: 10 (start) + 8 (len) = 18.
    #   Column for "line two" end: 1 (start) + 8 (len) = 9.
    #   Column for "line three" end: 1 (start) + 10 (len) = 11.
