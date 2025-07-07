# This BDD feature file corresponds to the TestLexConfig function in:
# ./hclwrite/parser_test.go
#
# It covers the behavior of hclwrite's internal lexer (`lexConfig`),
# focusing on how it produces hclwrite.Token objects that include
# spacing information for formatting preservation.

Feature: HCL Write - Lexical Configuration Scanning (lexConfig)
  This feature describes the tokenization process performed by `hclwrite.lexConfig`,
  which is internal to the `hclwrite` package. This lexer is designed to capture
  not only the token types and their byte values but also the amount of whitespace
  preceding each token, which is crucial for preserving formatting during HCL
  modification and regeneration.

  Background:
    Given an HCL writing context where `lexConfig` is used for tokenization

  Scenario Outline: Tokenizing HCL input using lexConfig
    Given the HCL input string:
      """
      <hcl_input>
      """
    When the input string is tokenized by `lexConfig`
    Then the resulting sequence of `hclwrite.Token` objects should be:
      | Type                | Bytes        | SpacesBefore |
      | <token_type_1>      | <bytes_1>    | <spaces_1>   |
      | <token_type_2>      | <bytes_2>    | <spaces_2>   |
      # ... more tokens ...
      | <token_type_N>      | <bytes_N>    | <spaces_N>   |
      | TokenEOF            | ""           | <spaces_eof> |

    Examples:
      | hcl_input | expected_tokens_table_description                                 |
      | `a  b `   | Two idents 'a' (0 spaces), 'b' (2 spaces), EOF (1 space)            |
      # For the complex example, the table will be explicitly listed below.

  Scenario: Tokenizing a structured HCL input with lexConfig
    Given the HCL input string:
      """

      foo "bar" "baz" {
          pizza = " cheese "
      }
      """
      # Note: leading newline in the input string
    When the input string is tokenized by `lexConfig`
    Then the resulting sequence of `hclwrite.Token` objects should be:
      | Type                | Bytes        | SpacesBefore |
      | TokenNewline        | `\n`         | 0            |
      | TokenIdent          | `foo`        | 0            |
      | TokenOQuote         | `"`          | 1            |
      | TokenQuotedLit      | `bar`        | 0            |
      | TokenCQuote         | `"`          | 0            |
      | TokenOQuote         | `"`          | 1            |
      | TokenQuotedLit      | `baz`        | 0            |
      | TokenCQuote         | `"`          | 0            |
      | TokenOBrace         | `{`          | 1            |
      | TokenNewline        | `\n`         | 0            |
      | TokenIdent          | `pizza`      | 4            |
      | TokenEqual          | `=`          | 1            |
      | TokenOQuote         | `"`          | 1            |
      | TokenQuotedLit      | ` cheese `   | 0            |
      | TokenCQuote         | `"`          | 0            |
      | TokenNewline        | `\n`         | 0            |
      | TokenCBrace         | `}`          | 0            |
      | TokenNewline        | `\n`         | 0            |
      | TokenEOF            | ""           | 0            |

    # Notes for the table in Scenario Outline:
    # - The `expected_tokens_table_description` in the Examples table is a summary.
    #   The step definition for that Scenario Outline would need to parse this description
    #   or have predefined tables for each example name.
    # - For the specific "Tokenizing a structured HCL input" scenario, the full token table is provided directly.
    # - Token Types are from hclsyntax (e.g., TokenIdent, TokenOQuote, TokenNewline, TokenEOF).
    # - Bytes are the literal byte sequence of the token.
    # - SpacesBefore is the count of whitespace characters preceding the token.
```
