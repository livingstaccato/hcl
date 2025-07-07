# Covers tests in ./json/scanner_test.go
# Specifically, TestScan

Feature: JSON HCL Token Scanner
  This feature tests the `scan` function, which tokenizes a raw JSON HCL input
  byte slice into a sequence of tokens. It verifies correct token types,
  byte content, and source range tracking for various JSON constructs and
  whitespace.

  Scenario Outline: Scanning various JSON inputs
    Given a JSON input string: "<input_json>"
    When the input is scanned starting at Line 1, Column 1, Byte 0
    Then the resulting sequence of tokens should be:
      | Type         | Bytes        | Start       | End         |
      | <TokenType1> | <TokenBytes1>| <TokenStart1> | <TokenEnd1> |
      | <TokenType2> | <TokenBytes2>| <TokenStart2> | <TokenEnd2> |
      # ... potentially more tokens
      | tokenEOF     |              | <EOFStart>    | <EOFEnd>    |

    Examples:
      | input_json    | TokenType1  | TokenBytes1 | TokenStart1       | TokenEnd1         | TokenType2  | TokenBytes2 | TokenStart2       | TokenEnd2         | EOFStart          | EOFEnd            |
      | ``            |             |             |                   |                   |             |             |                   |                   | L1C1 B0           | L1C1 B0           | # Empty input
      | `   `         |             |             |                   |                   |             |             |                   |                   | L1C4 B3           | L1C4 B3           | # Whitespace only
      | `{}`          | tokenBraceO | `{`         | L1C1 B0           | L1C2 B1           | tokenBraceC | `}`         | L1C2 B1           | L1C3 B2           | L1C3 B2           | L1C3 B2           |
      | `][`          | tokenBrackC | `]`         | L1C1 B0           | L1C2 B1           | tokenBrackO | `[`         | L1C2 B1           | L1C3 B2           | L1C3 B2           | L1C3 B2           |
      | `:,`          | tokenColon  | `:`         | L1C1 B0           | L1C2 B1           | tokenComma  | `,`         | L1C2 B1           | L1C3 B2           | L1C3 B2           | L1C3 B2           |
      | `1`           | tokenNumber | `1`         | L1C1 B0           | L1C2 B1           |             |             |                   |                   | L1C2 B1           | L1C2 B1           |
      | `  1`         | tokenNumber | `1`         | L1C3 B2           | L1C4 B3           |             |             |                   |                   | L1C4 B3           | L1C4 B3           |
      | `  12`        | tokenNumber | `12`        | L1C3 B2           | L1C5 B4           |             |             |                   |                   | L1C5 B4           | L1C5 B4           |
      | `1 2`         | tokenNumber | `1`         | L1C1 B0           | L1C2 B1           | tokenNumber | `2`         | L1C3 B2           | L1C4 B3           | L1C4 B3           | L1C4 B3           |
      | "\n1\n 2"     | tokenNumber | `1`         | L2C1 B1           | L2C2 B2           | tokenNumber | `2`         | L3C2 B4           | L3C3 B5           | L3C3 B5           | L3C3 B5           |
      | `-1 2.5`      | tokenNumber | `-1`        | L1C1 B0           | L1C3 B2           | tokenNumber | `2.5`       | L1C4 B3           | L1C7 B6           | L1C7 B6           | L1C7 B6           |
      | `true`        | tokenKeyword| `true`      | L1C1 B0           | L1C5 B4           |             |             |                   |                   | L1C5 B4           | L1C5 B4           |
      | `[true]`      | tokenBrackO | `[`         | L1C1 B0           | L1C2 B1           | tokenKeyword| `true`      | L1C2 B1           | L1C6 B5           | L1C6 B5           | L1C6 B5           | # Second token is keyword, third is BrackC, then EOF
      | `""`          | tokenString | `""`        | L1C1 B0           | L1C3 B2           |             |             |                   |                   | L1C3 B2           | L1C3 B2           |
      | `"hello"`     | tokenString | `"hello"`   | L1C1 B0           | L1C8 B7           |             |             |                   |                   | L1C8 B7           | L1C8 B7           |
      | `"he\\\"llo"` | tokenString | `"he\\"llo"`| L1C1 B0           | L1C10 B9          |             |             |                   |                   | L1C10 B9          | L1C10 B9          |
      | `"hello\\\\"` | tokenString | `"hello\\\\"`| L1C1 B0           | L1C10 B9          |             |             |                   |                   | L1C10 B9          | L1C10 B9          | # Note: original test had `1` after string, this example simplifies.
      | `"🇬🇧"`        | tokenString | `"🇬🇧"`      | L1C1 B0           | L1C4 B10          |             |             |                   |                   | L1C4 B10          | L1C4 B10          | # Column count differs due to multi-byte char
      | `"á́́́́́́́"`    | tokenString | `"á́́́́́́́"`| L1C1 B0           | L1C4 B19          |             |             |                   |                   | L1C4 B19          | L1C4 B19          | # String with many combining accents
      | `&`           | tokenInvalid| `&`         | L1C1 B0           | L1C2 B1           |             |             |                   |                   | L1C2 B1           | L1C2 B1           | # Invalid character

  # Notes for the token table:
  # - If TokenType/Bytes/Start/End for a subsequent token (e.g., TokenType2) are blank, it means fewer tokens were produced before EOF.
  # - The example for `[true]` is simplified in the Gherkin table for brevity. The full sequence is [BrackO, Keyword(true), BrackC, EOF].
  # - The example for `"hello\\\\"` is simplified; the original Go test had ` 1` after it.
  # - Source positions are Line Column ByteOffset (e.g., L1C1 B0).
  # - tokenEOF will always be the last token. Its Bytes are nil.
  # - The Bytes column for tokenEOF is intentionally left blank.
  # - The Start/End for tokenEOF indicates the position after the last significant token or start of file if empty.
