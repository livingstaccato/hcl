# Covers tests in ./hclsyntax/scan_tokens_test.go
# Specifically, TestScanTokens_normal and TestScanTokens_template

Feature: HCL Syntax - Token Scanning
  This feature tests the `scanTokens` function, which tokenizes raw HCL input
  into a sequence of `hclsyntax.Token` objects. It covers two scanning modes:
  'normal' for general HCL syntax and 'template' for content within strings
  and heredocs.

  Scenario Outline: Scanning HCL input in 'normal' mode
    Given an HCL input string: "<input_string>"
    When the input is scanned in 'normal' mode starting at Line 1, Column 1, Byte 0
    Then the resulting sequence of tokens should be: <expected_tokens_table>

    Examples:
      | input_string           | expected_tokens_table                                                                                                                                                              |
      | `""`                   | EOF(L1C1 B0)                                                                                                                                                                       | # Empty input
      | `" "`                  | EOF(L1C2 B1)                                                                                                                                                                       | # Whitespace only
      | `"\n\n"`               | NL(L1C1 B0-L2C1 B1), NL(L2C1 B1-L3C1 B2), EOF(L3C1 B2)                                                                                                                             | # Multiple newlines
      | `"\xef\xbb\xbf"`       | EOF(L1C1 B3)                                                                                                                                                                       | # UTF-8 BOM (ignored, but range advances)
      | `" \xef\xbb\xbf"`      | Invalid(L1C2 B1-L1C3 B4 Bytes:"\xef\xbb\xbf"), EOF(L1C3 B4)                                                                                                                         | # Non-leading BOM is invalid
      | `"\xfe\xff"`           | BadUTF8(L1C1 B0-L1C2 B1 Bytes:"\xfe"), BadUTF8(L1C2 B1-L1C3 B2 Bytes:"\xff"), EOF(L1C3 B2)                                                                                           | # UTF-16 BOM is invalid
      | `"1"`                  | NumberLit(L1C1 B0-L1C2 B1 Bytes:"1"), EOF(L1C2 B1)                                                                                                                                  | # Single digit number
      | `"12.3"`               | NumberLit(L1C1 B0-L1C5 B4 Bytes:"12.3"), EOF(L1C5 B4)                                                                                                                               | # Decimal number
      | `"1e+2"`               | NumberLit(L1C1 B0-L1C5 B4 Bytes:"1e+2"), EOF(L1C5 B4)                                                                                                                               | # Number with exponent
      | `"hello"`              | Ident(L1C1 B0-L1C6 B5 Bytes:"hello"), EOF(L1C6 B5)                                                                                                                                  | # Identifier
      | `"_ello"`              | Ident(L1C1 B0-L1C6 B5 Bytes:"_ello"), EOF(L1C6 B5)                                                                                                                                  | # Identifier starting with underscore
      | `"hel-o"`              | Ident(L1C1 B0-L1C6 B5 Bytes:"hel-o"), EOF(L1C6 B5)                                                                                                                                  | # Identifier with hyphen
      | `"héllo"`             | Ident(L1C1 B0-L1C6 B7 Bytes:"héllo"), EOF(L1C6 B7)                                                                                                                                 | # Identifier with combining char (e acute)
      | `"::"`                 | DoubleColon(L1C1 B0-L1C3 B2 Bytes:"::"), EOF(L1C3 B2)                                                                                                                               | # Double colon
      | `"a::b"`               | Ident(L1C1 B0-L1C2 B1 Bytes:"a"), DoubleColon(L1C2 B1-L1C4 B3 Bytes:"::"), Ident(L1C4 B3-L1C5 B4 Bytes:"b"), EOF(L1C5 B4)                                                           | # Identifiers with double colon
      | `""`                   | OQuote(L1C1 B0-L1C2 B1), CQuote(L1C2 B1-L1C3 B2), EOF(L1C3 B2)                                                                                                                      | # Empty quoted string
      | `"hello"`              | OQuote(L1C1 B0-L1C2 B1), QuotedLit(L1C2 B1-L1C7 B6 Bytes:"hello"), CQuote(L1C7 B6-L1C8 B7), EOF(L1C8 B7)                                                                             | # Simple quoted string
      | `"hello $$"`           | OQuote(L1C1 B0-L1C2 B1), QuotedLit(L1C2 B1-L1C8 B7 Bytes:"hello "), QuotedLit(L1C8 B7-L1C9 B8 Bytes:"$"), QuotedLit(L1C9 B8-L1C10 B9 Bytes:"$"), CQuote(L1C10 B9-L1C11 B10), EOF(L1C11 B10) | # Escaped dollar in string
      | `"${1}"`               | OQuote(L1C1 B0-L1C2 B1), TemplateInterp(L1C2 B1-L1C4 B3), NumberLit(L1C4 B3-L1C5 B4 Bytes:"1"), TemplateSeqEnd(L1C5 B4-L1C6 B5), CQuote(L1C6 B5-L1C7 B6), EOF(L1C7 B6)                 | # Interpolation in string
      | `"%{a}"`               | OQuote(L1C1 B0-L1C2 B1), TemplateControl(L1C2 B1-L1C4 B3), Ident(L1C4 B3-L1C5 B4 Bytes:"a"), TemplateSeqEnd(L1C5 B4-L1C6 B5), CQuote(L1C6 B5-L1C7 B6), EOF(L1C7 B6)                   | # Control sequence in string
      | `"${"${a}"}"`          | OQuote(L1C1 B0-L1C2 B1), TI(L1C2 B1), OQuote(L1C4 B3), TI(L1C5 B4), Id(L1C7 B6 "a"), TSE(L1C8 B7), CQuote(L1C9 B8), TSE(L1C10 B9), CQuote(L1C11 B10), EOF(L1C12 B11)           | # Nested interpolation
      | `<<EOT\nhello\nEOT\n`  | OHeredoc(L1C1 B0-L2C1 B6 Bytes:"<<EOT\n"), StringLit(L2C1 B6-L3C1 B12 Bytes:"hello\n"), CHeredoc(L3C1 B12-L3C4 B15 Bytes:"EOT"), NL(L3C4 B15-L4C1 B16), EOF(L4C1 B16)        | # Simple heredoc
      | `<<-EOT\n  h\n EOT\n` | OHeredoc(L1C1 B0-L2C1 B7 Bytes:"<<-EOT\n"), StringLit(L2C1 B7-L3C1 B11 Bytes:"  h\n"), CHeredoc(L3C1 B11-L3C5 B15 Bytes:" EOT"), NL(L3C5 B15-L4C1 B16), EOF(L4C1 B16)      | # Indented heredoc with marker indent
      | ` (1 + 2) * 3 `        | OParen(L1C2 B1), Num(L1C3 B2 "1"), Plus(L1C5 B4), Num(L1C7 B6 "2"), CParen(L1C8 B7), Star(L1C10 B9), Num(L1C12 B11 "3"), EOF(L1C14 B13)                                       | # Combination of operators
      | `9%8`                  | Num(L1C1 B0 "9"), Percent(L1C2 B1), Num(L1C3 B2 "8"), EOF(L1C4 B3)                                                                                                                   | # Modulo operator
      | `"\n_a = 1\n"`         | NL(L1C1 B0), Id(L2C1 B1 "_a"), Eq(L2C4 B3), Num(L2C6 B5 "1"), NL(L2C7 B6), EOF(L3C1 B7)                                                                                              | # Assignment with newlines
      | `"# hello\n"`          | Comment(L1C1 B0-L2C1 B8 Bytes:"# hello\n"), EOF(L2C1 B8)                                                                                                                            | # Hash comment
      | `"// hello\n"`         | Comment(L1C1 B0-L2C1 B9 Bytes:"// hello\n"), EOF(L2C1 B9)                                                                                                                           | # Slash comment
      | `"/* hello */"`        | Comment(L1C1 B0-L1C12 B11 Bytes:"/* hello */"), EOF(L1C12 B11)                                                                                                                       | # Block comment
      | `"🌻"`                 | Invalid(L1C1 B0-L1C2 B4 Bytes:"🌻"), EOF(L1C2 B4)                                                                                                                                   | # Invalid character (emoji)
      | `"|"`                  | BitwiseOr(L1C1 B0-L1C2 B1 Bytes:"|"), EOF(L1C2 B1)                                                                                                                                   | # Bitwise OR (lexed, parser might reject)
      | `"\x80"`               | BadUTF8(L1C1 B0-L1C2 B1 Bytes:"\x80"), EOF(L1C2 B1)                                                                                                                                 | # Bad UTF-8 sequence
      | `"\t\t"`               | EOF(L1C3 B2)                                                                                                                                                                       | # Tabs only

  Scenario Outline: Scanning HCL template content in 'template' mode
    Given an HCL input string: "<input_string>"
    When the input is scanned in 'template' mode starting at Line 1, Column 1, Byte 0
    Then the resulting sequence of tokens should be: <expected_tokens_table>

    Examples:
      | input_string        | expected_tokens_table                                                                                                                                                              |
      | `""`                | EOF(L1C1 B0)                                                                                                                                                                       | # Empty template
      | `" hello "`         | StringLit(L1C1 B0-L1C8 B7 Bytes:" hello "), EOF(L1C8 B7)                                                                                                                            | # Simple literal in template
      | `"\nhello\n"`       | StringLit(L1C1 B0-L2C1 B1 Bytes:"\n"), StringLit(L2C1 B1-L3C1 B7 Bytes:"hello\n"), EOF(L3C1 B7)                                                                                     | # Literal with newlines
      | `"hello ${foo} helo"`| StringLit(L1C1 B0-L1C7 B6 Bytes:"hello "), TI(L1C7 B6), Id(L1C9 B8 "foo"), TSE(L1C12 B11), StringLit(L1C13 B12-L1C19 B18 Bytes:" helo"), EOF(L1C19 B18)                            | # Interpolation in template
      | `"hello ${~foo~} helo"`| StringLit(L1C1 B0-L1C7 B6 Bytes:"hello "), TI(L1C7 B6 Bytes:"${~"), Id(L1C10 B9 "foo"), TSE(L1C13 B12 Bytes:"~}"), StringLit(L1C15 B14-L1C21 B20 Bytes:" helo"), EOF(L1C21 B20) | # Interpolation with trim markers

    # Notes for token table format:
    # - Token(Range Bytes:"bytes_if_any"), e.g., EOF(L1C1 B0), Ident(L1C1 B0-L1C6 B5 Bytes:"hello")
    # - TI = TemplateInterp, TSE = TemplateSeqEnd, Id = Ident, Num = NumberLit, Eq = Equal, NL = Newline.
    # - For brevity, some token details (like Bytes) are omitted if clear from Type and context.
    # - The ranges LxCxB format means Line x, Column x, Byte x. LxCxB-LxCxB is Start-End.
    # - The nested interpolation example for normal mode is complex; its Gherkin representation is simplified.
    # - Heredoc examples show OHeredoc, StringLit (for content), CHeredoc, and trailing Newline/EOF.
    # - Invalid heredoc markers (e.g. `<<EOF `) are lexed as individual tokens.
