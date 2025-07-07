# This BDD feature file corresponds to the Go test file:
# ./hclsyntax/scan_tokens_test.go
#
# It covers the tokenization of HCL native syntax and template content.
# Primarily tests ScanTokens with scanNormal and scanTemplate modes.

Feature: HCL Native Syntax Tokenization
  This feature describes how HCL source text is broken down into a sequence of tokens,
  including identifiers, literals, operators, punctuation, comments, and template markers.

  Background:
    Given HCL source text is being tokenized

  Scenario Outline: Basic Tokenization and Whitespace Handling
    Given the HCL input string: "<input_string>"
    When the input is tokenized in 'normal' mode
    Then the resulting token sequence should be:
      | Type         | Bytes        | Start (L,C,B) | End (L,C,B) |
      | <token_type> | <byte_value> | <start_pos>   | <end_pos>   |
      | ...          | ...          | ...           | ...         |
    And the final token should be TokenEOF

    Examples:
      | input_string | token_type | byte_value | start_pos | end_pos   |
      | ``           | TokenEOF   | ""         | 1,1,0     | 1,1,0     |
      | ` `          | TokenEOF   | ""         | 1,2,1     | 1,2,1     | # Whitespace consumed
      | `\n\n`       | TokenNewline | `\n`       | 1,1,0     | 2,1,1     |
      |              | TokenNewline | `\n`       | 2,1,1     | 3,1,2     |
      |              | TokenEOF   | ""         | 3,1,2     | 3,1,2     |
      # UTF-8 BOM
      | `\xef\xbb\xbf` | TokenEOF | ""         | 1,1,3     | 1,1,3     | # Leading BOM ignored, bytes counted
      | ` \xef\xbb\xbf`| TokenInvalid|`\xef\xbb\xbf`| 1,2,1  | 1,3,4     | # Non-leading BOM is invalid
      |              | TokenEOF   | ""         | 1,3,4     | 1,3,4     |
      | `\xfe\xff`   | TokenBadUTF8|`\xfe`      | 1,1,0     | 1,2,1     | # UTF-16 BOM invalid
      |              | TokenBadUTF8|`\xff`      | 1,2,1     | 1,3,2     |
      |              | TokenEOF   | ""         | 1,3,2     | 1,3,2     |

  Scenario Outline: Tokenizing Numeric Literals
    Given the HCL input string: "<input_string>"
    When the input is tokenized in 'normal' mode
    Then the first token should be Type:TokenNumberLit, Bytes:"<input_string>", Range:<range>
    And the second token should be TokenEOF

    Examples:
      | input_string | range             |
      | `1`          | (1,1,0)-(1,2,1)   |
      | `12`         | (1,1,0)-(1,3,2)   |
      | `12.3`       | (1,1,0)-(1,5,4)   |
      | `1e2`        | (1,1,0)-(1,4,3)   |
      | `1e+2`       | (1,1,0)-(1,5,4)   |

  Scenario Outline: Tokenizing Identifiers
    Given the HCL input string: "<input_string>"
    When the input is tokenized in 'normal' mode
    Then the first token should be Type:TokenIdent, Bytes:"<input_string>", Range:<range>
    And the second token should be TokenEOF

    Examples:
      | input_string | range             |
      | `hello`      | (1,1,0)-(1,6,5)   |
      | `_ello`      | (1,1,0)-(1,6,5)   |
      | `hel_o`      | (1,1,0)-(1,6,5)   |
      | `hel-o`      | (1,1,0)-(1,6,5)   | # Hyphens allowed in idents
      | `h3ll0`      | (1,1,0)-(1,6,5)   |
      | `héllo`     | (1,1,0)-(1,6,7)   | # Unicode identifier (e with acute accent)

  Scenario: Tokenizing Qualified Identifiers (Namespaces)
    Given the HCL input string: "a::b"
    When the input is tokenized in 'normal' mode
    Then the token sequence should be:
      | Type             | Bytes | Start (L,C,B) | End (L,C,B) |
      | TokenIdent       | `a`   | 1,1,0         | 1,2,1       |
      | TokenDoubleColon | `::`  | 1,2,1         | 1,4,3       |
      | TokenIdent       | `b`   | 1,4,3         | 1,5,4       |
      | TokenEOF         | ""    | 1,5,4         | 1,5,4       |

  Scenario Outline: Tokenizing Quoted String Literals (No Interpolations)
    Given the HCL input string: "<input_string>"
    When the input is tokenized in 'normal' mode
    Then the token sequence (excluding final EOF) should be <expected_tokens_json>
      # expected_tokens_json is a JSON list of {type, bytes, start, end} objects

    Examples:
      | input_string          | expected_tokens_json                                                                                                |
      | `""`                  | `[{"type":"TokenOQuote","bytes":"\"","start":"1,1,0","end":"1,2,1"}, {"type":"TokenCQuote","bytes":"\"","start":"1,2,1","end":"1,3,2"}]` |
      | `"hello"`             | `[{"type":"TokenOQuote","bytes":"\"","start":"1,1,0","end":"1,2,1"}, {"type":"TokenQuotedLit","bytes":"hello","start":"1,2,1","end":"1,7,6"}, {"type":"TokenCQuote","bytes":"\"","start":"1,7,6","end":"1,8,7"}]` |
      | `"hello, \\\"world\\\"!"` | `[{"type":"TokenOQuote","bytes":"\"","start":"1,1,0","end":"1,2,1"}, {"type":"TokenQuotedLit","bytes":"hello, \\\"world\\\"!","start":"1,2,1","end":"1,19,18"}, {"type":"TokenCQuote","bytes":"\"","start":"1,19,18","end":"1,20,19"}]` |
      | `"hello $$"`          | `[{"type":"TokenOQuote","bytes":"\"","start":"1,1,0","end":"1,2,1"}, {"type":"TokenQuotedLit","bytes":"hello ","start":"1,2,1","end":"1,8,7"}, {"type":"TokenQuotedLit","bytes":"$","start":"1,8,7","end":"1,9,8"}, {"type":"TokenQuotedLit","bytes":"$","start":"1,9,8","end":"1,10,9"}, {"type":"TokenCQuote","bytes":"\"","start":"1,10,9","end":"1,11,10"}]` |

  Scenario Outline: Tokenizing String Templates with Interpolations and Controls
    Given the HCL input string: "<input_string>"
    When the input is tokenized in 'normal' mode
    Then the token sequence (excluding final EOF) should be <expected_tokens_json>

    Examples:
      | input_string   | expected_tokens_json |
      | `"${1}"`       | `[{"type":"TokenOQuote","bytes":"\"","start":"1,1,0","end":"1,2,1"}, {"type":"TokenTemplateInterp","bytes":"${","start":"1,2,1","end":"1,4,3"}, {"type":"TokenNumberLit","bytes":"1","start":"1,4,3","end":"1,5,4"}, {"type":"TokenTemplateSeqEnd","bytes":"}","start":"1,5,4","end":"1,6,5"}, {"type":"TokenCQuote","bytes":"\"","start":"1,6,5","end":"1,7,6"}]` |
      | `"%{a}"`       | `[{"type":"TokenOQuote","bytes":"\"","start":"1,1,0","end":"1,2,1"}, {"type":"TokenTemplateControl","bytes":"%{","start":"1,2,1","end":"1,4,3"}, {"type":"TokenIdent","bytes":"a","start":"1,4,3","end":"1,5,4"}, {"type":"TokenTemplateSeqEnd","bytes":"}","start":"1,5,4","end":"1,6,5"}, {"type":"TokenCQuote","bytes":"\"","start":"1,6,5","end":"1,7,6"}]` |
      | `"${"${a}"}"`  | `[{"type":"TokenOQuote","bytes":"\"","start":"1,1,0","end":"1,2,1"}, {"type":"TokenTemplateInterp","bytes":"${","start":"1,2,1","end":"1,4,3"}, {"type":"TokenOQuote","bytes":"\"","start":"1,4,3","end":"1,5,4"}, {"type":"TokenTemplateInterp","bytes":"${","start":"1,5,4","end":"1,7,6"}, {"type":"TokenIdent","bytes":"a","start":"1,7,6","end":"1,8,7"}, {"type":"TokenTemplateSeqEnd","bytes":"}","start":"1,8,7","end":"1,9,8"}, {"type":"TokenCQuote","bytes":"\"","start":"1,9,8","end":"1,10,9"}, {"type":"TokenTemplateSeqEnd","bytes":"}","start":"1,10,9","end":"1,11,10"}, {"type":"TokenCQuote","bytes":"\"","start":"1,11,10","end":"1,12,11"}]` |

  Scenario Outline: Tokenizing Heredoc Templates
    Given the HCL input string: "<heredoc_input>"
    When the input is tokenized in 'normal' mode
    Then the token sequence (excluding final EOF) should be <expected_tokens_json>

    Examples:
      | heredoc_input                         | expected_tokens_json |
      | `<<EOT\nhello world\nEOT\n`           | `[{"type":"TokenOHeredoc","bytes":"<<EOT\\n","start":"1,1,0","end":"2,1,6"}, {"type":"TokenStringLit","bytes":"hello world\\n","start":"2,1,6","end":"3,1,18"}, {"type":"TokenCHeredoc","bytes":"EOT","start":"3,1,18","end":"3,4,21"}, {"type":"TokenNewline","bytes":"\\n","start":"3,4,21","end":"4,1,22"}]` |
      | `<<-EOT\n  hello world\n EOT\n`       | `[{"type":"TokenOHeredoc","bytes":"<<-EOT\\n","start":"1,1,0","end":"2,1,7"}, {"type":"TokenStringLit","bytes":"  hello world\\n","start":"2,1,7","end":"3,1,21"}, {"type":"TokenCHeredoc","bytes":" EOT","start":"3,1,21","end":"3,5,25"}, {"type":"TokenNewline","bytes":"\\n","start":"3,5,25","end":"4,1,26"}]` |
      | `<<EOT\n${name}EOT\nEOT\n`            | `[{"type":"TokenOHeredoc","bytes":"<<EOT\\n","start":"1,1,0","end":"2,1,6"}, {"type":"TokenTemplateInterp","bytes":"${","start":"2,1,6","end":"2,3,8"}, {"type":"TokenIdent","bytes":"name","start":"2,3,8","end":"2,7,12"}, {"type":"TokenTemplateSeqEnd","bytes":"}","start":"2,7,12","end":"2,8,13"}, {"type":"TokenStringLit","bytes":"EOT\\n","start":"2,8,13","end":"3,1,17"}, {"type":"TokenCHeredoc","bytes":"EOT","start":"3,1,17","end":"3,4,20"}, {"type":"TokenNewline","bytes":"\\n","start":"3,4,20","end":"4,1,21"}]` |

  Scenario Outline: Tokenizing Operators and Punctuation
    Given the HCL input string: "<operator_or_punctuation>"
    When the input is tokenized in 'normal' mode
    Then the first token should be Type:<expected_token_type>, Bytes:"<operator_or_punctuation>", Range:<range>
    And the second token should be TokenEOF

    Examples:
      | operator_or_punctuation | expected_token_type | range           |
      | `+`                     | TokenPlus           | (1,1,0)-(1,2,1) |
      | `-`                     | TokenMinus          | (1,1,0)-(1,2,1) |
      | `*`                     | TokenStar           | (1,1,0)-(1,2,1) |
      | `/`                     | TokenSlash          | (1,1,0)-(1,2,1) |
      | `%`                     | TokenPercent        | (1,1,0)-(1,2,1) |
      | `==`                    | TokenEqualOp        | (1,1,0)-(1,3,2) |
      | `!=`                    | TokenNotEqual       | (1,1,0)-(1,3,2) |
      | `<`                     | TokenLessThan       | (1,1,0)-(1,2,1) |
      | `<=`                    | TokenLessThanEq     | (1,1,0)-(1,3,2) |
      | `>`                     | TokenGreaterThan    | (1,1,0)-(1,2,1) |
      | `>=`                    | TokenGreaterThanEq  | (1,1,0)-(1,3,2) |
      | `&&`                    | TokenAnd            | (1,1,0)-(1,3,2) |
      | `||`                    | TokenOr             | (1,1,0)-(1,3,2) |
      | `!`                     | TokenBang           | (1,1,0)-(1,2,1) |
      | `?`                     | TokenQuestion       | (1,1,0)-(1,2,1) |
      | `:`                     | TokenColon          | (1,1,0)-(1,2,1) |
      | `.`                     | TokenDot            | (1,1,0)-(1,2,1) |
      | `,`                     | TokenComma          | (1,1,0)-(1,2,1) |
      | `(`                     | TokenOParen         | (1,1,0)-(1,2,1) |
      | `)`                     | TokenCParen         | (1,1,0)-(1,2,1) |
      | `[`                     | TokenOBrack         | (1,1,0)-(1,2,1) |
      | `]`                     | TokenCBrack         | (1,1,0)-(1,2,1) |
      | `{`                     | TokenOBrace         | (1,1,0)-(1,2,1) |
      | `}`                     | TokenCBrace         | (1,1,0)-(1,2,1) |
      | `...`                   | TokenEllipsis       | (1,1,0)-(1,4,3) |

  Scenario Outline: Tokenizing Comments
    Given the HCL input string: "<comment_string>"
    When the input is tokenized in 'normal' mode
    Then the first token should be Type:TokenComment, Bytes:"<expected_bytes>", Range:<range>
    And the second token should be TokenEOF

    Examples:
      | comment_string | expected_bytes | range             |
      | `# hello\n`    | `# hello\n`    | (1,1,0)-(2,1,8)   |
      | `// hello\n`   | `// hello\n`   | (1,1,0)-(2,1,9)   |
      | `/* hello */` | `/* hello */` | (1,1,0)-(1,12,11) |
      | `// hello`     | `// hello`     | (1,1,0)-(1,9,8)   | # No trailing newline

  Scenario Outline: Tokenizing Invalid Sequences
    Given the HCL input string: "<input_string>"
    When the input is tokenized in 'normal' mode
    Then the first token should be Type:<expected_token_type>, Bytes:"<bytes>", Range:<range>
    And the second token should be TokenEOF

    Examples:
      | input_string | expected_token_type | bytes      | range           |
      | `🌻`         | TokenInvalid        | `🌻`       | (1,1,0)-(1,2,4)   | # Sunflower emoji
      | `\x80`       | TokenBadUTF8        | `\x80`     | (1,1,0)-(1,2,1)   | # Invalid UTF-8 start

  Scenario Outline: Tokenizing Template Content (scanTemplate mode)
    Given the HCL template content string: "<input_string>"
    When the input is tokenized in 'template' mode
    Then the token sequence (excluding final EOF) should be <expected_tokens_json>

    Examples:
      | input_string         | expected_tokens_json |
      | ` hello `            | `[{"type":"TokenStringLit","bytes":" hello ","start":"1,1,0","end":"1,8,7"}]` |
      | `\nhello\n`          | `[{"type":"TokenStringLit","bytes":"\\n","start":"1,1,0","end":"2,1,1"}, {"type":"TokenStringLit","bytes":"hello\\n","start":"2,1,1","end":"3,1,7"}]` |
      | `hello ${foo} hello` | `[{"type":"TokenStringLit","bytes":"hello ","start":"1,1,0","end":"1,7,6"}, {"type":"TokenTemplateInterp","bytes":"${","start":"1,7,6","end":"1,9,8"}, {"type":"TokenIdent","bytes":"foo","start":"1,9,8","end":"1,12,11"}, {"type":"TokenTemplateSeqEnd","bytes":"}","start":"1,12,11","end":"1,13,12"}, {"type":"TokenStringLit","bytes":" hello","start":"1,13,12","end":"1,19,18"}]` |
      | `hello ${~foo~} hello`| `[{"type":"TokenStringLit","bytes":"hello ","start":"1,1,0","end":"1,7,6"}, {"type":"TokenTemplateInterp","bytes":"${~","start":"1,7,6","end":"1,10,9"}, {"type":"TokenIdent","bytes":"foo","start":"1,10,9","end":"1,13,12"}, {"type":"TokenTemplateSeqEnd","bytes":"~}","start":"1,13,12","end":"1,15,14"}, {"type":"TokenStringLit","bytes":" hello","start":"1,15,14","end":"1,21,20"}]` |

    # Notes for table values:
    # - <range> is in format (StartLine,StartCol,StartByte)-(EndLine,EndCol,EndByte)
    # - <expected_tokens_json> is a JSON string representing a list of token objects.
    #   Each object has "type" (string), "bytes" (string), "start" (L,C,B string), "end" (L,C,B string).
    # - Bytes for tokens like newlines are represented as `\n`.
    # - Some complex token sequences in examples are simplified or focus on the primary tokens.
    # - The distinction between TokenQuotedLit (from scanNormal within quotes) and TokenStringLit (from scanTemplate or heredoc content) is maintained.
```
