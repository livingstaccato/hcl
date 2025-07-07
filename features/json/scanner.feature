# Covers internal JSON token scanning logic in ./json/scanner.go
# Based on test cases in ./json/scanner_test.go (TestScan)

Feature: HCL JSON Low-Level Token Scanner
  This feature tests the internal `scan` function, which tokenizes a raw JSON HCL
  input byte slice into a sequence of `json.token` objects. It verifies correct
  token types, byte content, and HCL source range tracking for various JSON
  constructs, whitespace, and special characters.

  Scenario Outline: Scanning various JSON inputs into tokens
    Given a JSON input string: "<input_json_string>"
    When the input is scanned using the internal `scan` function with filename "" and initial position L1C1B0
    Then the resulting sequence of tokens should be:
      | Type         | Bytes        | Range (File:"", Start:[L,C,B]-End:[L,C,B]) |
      # Examples will populate this table structure.
      # The last token in a non-empty sequence will always be tokenEOF.
      <expected_tokens_table>

    Examples:
      | input_json_string | expected_tokens_table                                                                                                                               |
      | `""`              | tokenEOF(L1C1B0-L1C1B0)                                                                                                                             |
      | `"   "`           | tokenEOF(L1C4B3-L1C4B3)                                                                                                                             | # Whitespace only
      | `"{}"`            | tokenBraceO({ L1C1B0-L1C2B1) <br> tokenBraceC(} L1C2B1-L1C3B2) <br> tokenEOF(L1C3B2-L1C3B2)                                                            |
      | `"]["`            | tokenBrackC(] L1C1B0-L1C2B1) <br> tokenBrackO([ L1C2B1-L1C3B2) <br> tokenEOF(L1C3B2-L1C3B2)                                                            |
      | `":,"`            | tokenColon(: L1C1B0-L1C2B1) <br> tokenComma(, L1C2B1-L1C3B2) <br> tokenEOF(L1C3B2-L1C3B2)                                                             |
      | `"1"`             | tokenNumber(1 L1C1B0-L1C2B1) <br> tokenEOF(L1C2B1-L1C2B1)                                                                                            |
      | `"  1"`           | tokenNumber(1 L1C3B2-L1C4B3) <br> tokenEOF(L1C4B3-L1C4B3)                                                                                            | # Leading spaces
      | `"1 2"`           | tokenNumber(1 L1C1B0-L1C2B1) <br> tokenNumber(2 L1C3B2-L1C4B3) <br> tokenEOF(L1C4B3-L1C4B3)                                                            |
      | `"\n1\n 2"`       | tokenNumber(1 L2C1B1-L2C2B2) <br> tokenNumber(2 L3C2B4-L3C3B5) <br> tokenEOF(L3C3B5-L3C3B5)                                                            | # Newlines and spaces
      | `"-1 2.5"`        | tokenNumber(-1 L1C1B0-L1C3B2) <br> tokenNumber(2.5 L1C4B3-L1C7B6) <br> tokenEOF(L1C7B6-L1C7B6)                                                          |
      | `"true"`          | tokenKeyword(true L1C1B0-L1C5B4) <br> tokenEOF(L1C5B4-L1C5B4)                                                                                        |
      | `"[true]"`        | tokenBrackO([ L1C1B0-L1C2B1) <br> tokenKeyword(true L1C2B1-L1C6B5) <br> tokenBrackC(] L1C6B5-L1C7B6) <br> tokenEOF(L1C7B6-L1C7B6)                      |
      | `""`              | tokenString("" L1C1B0-L1C3B2) <br> tokenEOF(L1C3B2-L1C3B2)                                                                                          | # Empty string
      | `"hello"`         | tokenString("hello" L1C1B0-L1C8B7) <br> tokenEOF(L1C8B7-L1C8B7)                                                                                    |
      | `"he\\\"llo"`     | tokenString("he\\\"llo" L1C1B0-L1C10B9) <br> tokenEOF(L1C10B9-L1C10B9)                                                                                 | # Escaped quote in string
      | `"hello\\\\"`     | tokenString("hello\\\\" L1C1B0-L1C10B9) <br> tokenEOF(L1C10B9-L1C10B9)                                                                               | # Escaped backslash
      | `"🇬🇧"`            | tokenString("🇬🇧" L1C1B0-L1C4B10) <br> tokenEOF(L1C4B10-L1C4B10)                                                                                     | # Unicode, column count is 2, byte count 8 for 🇬🇧
      | `"á́́́́́́́"`        | tokenString("á́́́́́́́" L1C1B0-L1C4B19) <br> tokenEOF(L1C4B19-L1C4B19)                                                                                | # String with combining accents, column count 2
      | `"&"`             | tokenInvalid(& L1C1B0-L1C2B1) <br> tokenEOF(L1C2B1-L1C2B1)                                                                                           | # Invalid character

    # Notes for token table format:
    # - `TokenTypeName(BytesString LxCxBx-LxCxBx)` e.g., `tokenNumber(1 L1C1B0-L1C2B1)`.
    # - If BytesString is omitted, it's the default for the type (e.g., "{" for tokenBraceO).
    # - For tokenEOF, BytesString is empty.
    # - LxCxB format: Line, Column, Byte (0-indexed for Byte, 1-indexed for Line/Column).
    # - `<br>` is used to separate multiple tokens in the Gherkin table for readability.
    # - The scanner is lax; detailed validation of number/string/keyword content happens in the parser.
    # - Column counting for strings with multi-byte chars or combining accents relies on grapheme cluster scanning.
    # - Tab characters are counted as 2 columns by skipWhitespace.
