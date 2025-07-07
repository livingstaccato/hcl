# Covers tests in ./pos_scanner_test.go
# Specifically, TestPosScanner

Feature: HCL Range Scanner
  This feature tests the `NewRangeScanner` which is used to scan byte slices
  (representing HCL source code) line by line, tracking the source position (byte, line, column)
  and providing the bytes for each scanned token (line).

  Scenario Outline: Scanning input with various line endings and content
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

    # Notes for table values:
    # - Input strings are Go-escaped for newlines and unicode.
    # - `expected_lines_content`: A list of strings representing the byte content of each line.
    #   Unicode characters like 👩🏿 are represented directly.
    # - `expected_ranges`: A list of HCL Range strings, e.g., `L1C1(B0)-L1C6(B5)` means
    #   Start: Line 1, Column 1, Byte 0 and End: Line 1, Column 6, Byte 5.
    # - The byte offsets in ranges account for the width of newline characters (`\n` is 1 byte, `\r\n` is 2 bytes)
    #   and multi-byte UTF-8 characters. Column counts are based on Unicode characters.
