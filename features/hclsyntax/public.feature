# Covers tests in ./hclsyntax/public_test.go
# Specifically, TestValidIdentifier. (BenchmarkLexConfig is not a functional test case).

Feature: HCL Syntax - Public Utility Functions
  This feature tests public utility functions provided by the `hclsyntax` package.

  Scenario Outline: Validating HCL Identifiers
    Given an input string "<input_string>"
    When `ValidIdentifier` is called with the input string
    Then the result should be <is_valid>

    Examples:
      | input_string  | is_valid |
      | `""`            | false    | # Empty string
      | `"hello"`       | true     | # Simple valid identifier
      | `"hello.world"` | false    | # Contains dot
      | `"hello "`      | false    | # Trailing space
      | `" hello"`      | false    | # Leading space
      | `"hello\\n"`    | false    | # Contains newline
      | `"hello world"` | false    | # Contains space
      | `"aws_instance"`| true     | # Underscore allowed
      | `"aws.instance"`| false    | # Dot not allowed
      | `"foo-bar"`     | true     | # Hyphen allowed
      | `"foo--bar"`    | true     | # Multiple hyphens allowed
      | `"foo_"`        | true     | # Trailing underscore allowed
      | `"foo-"`        | true     | # Trailing hyphen allowed
      | `"_foobar"`     | true     | # Leading underscore allowed
      | `"-foobar"`     | false    | # Leading hyphen not allowed
      | `"blah1"`       | true     | # Ends with digit
      | `"blah1blah"`   | true     | # Contains digit
      | `"1blah1blah"`  | false    | # Starts with digit
      | `"héllo"`      | true     | # Unicode with combining accent (e acute)
      | `"Χαίρετε"`    | true     | # Greek
      | `"звать"`       | true     | # Cyrillic
      | `"今日は"`      | true     | # Japanese
      | `"\x80"`        | false    | # Invalid UTF-8 (continuation byte)
      | `"a\x80"`       | false    | # Invalid UTF-8 (continuation byte after valid char)

    # Note: Input strings are Go-escaped for special characters like newline.
    # The actual function takes a raw string.
