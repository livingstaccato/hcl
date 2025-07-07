# Covers tests in ./hclsyntax/token_test.go
# Specifically, TestCheckInvalidTokensTest

Feature: HCL Syntax - Invalid Token Detection
  This feature tests the lexer's ability to detect and report diagnostics
  for various invalid characters and unsupported operators that might appear
  in HCL source code.

  Scenario Outline: Detecting invalid tokens and unsupported operators
    Given an HCL input string: "<input_string>"
    When the input string is lexed using `LexConfig`
    Then at least one error diagnostic should be reported
    And one of the error diagnostics should have:
      Summary: "<expected_summary>"
      Detail: "<expected_detail>"

    Examples:
      | input_string          | expected_summary     | expected_detail                                                                                                                                        |
      | `block “invalid” {}`  | Invalid character    | "Curly quotes" are not valid here. These can sometimes be inadvertently introduced when sharing code via documents or discussion forums. It might help to replace the character with a "straight quote". |
      | `block 'invalid' {}`  | Invalid character    | Single quotes are not valid. Use double quotes (") to enclose strings.                                                                               |
      | "block `invalid` {}"  | Invalid character    | The "`" character is not valid. To create a multi-line string, use the "heredoc" syntax, like "<<EOT".                                                |
      | `foo = a & b`         | Unsupported operator | Bitwise operators are not supported. Did you mean boolean AND ("&&")?                                                                                  |
      | `foo = a | b`         | Unsupported operator | Bitwise operators are not supported. Did you mean boolean OR ("||")?                                                                                   |
      | `foo = ~a`            | Unsupported operator | Bitwise operators are not supported. Did you mean boolean NOT ("!")?                                                                                   |
