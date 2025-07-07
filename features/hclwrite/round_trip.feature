# Covers tests in ./hclwrite/round_trip_test.go
# Specifically, TestRoundTripVerbatim and TestRoundTripFormat.
# TestRoundTripSafeConcurrent is a race condition test, not a functional BDD case.

Feature: HCL Write - Round Trip Parsing, Formatting, and Evaluation
  This feature tests the ability of the `hclwrite` package to parse HCL source,
  potentially format it, and then ensure that the semantic meaning (evaluated values)
  remains consistent. It also tests that verbatim parsing and writing preserves
  the exact byte sequence, including comments and whitespace.

  Scenario Outline: Verbatim round trip (Parse then WriteTo)
    Given an HCL input string:
      """
      <input_hcl>
      """
    When the input string is parsed using `hclwrite.parse` (internal)
    Then no parsing diagnostics should be reported
    When the parsed file is written out using `file.WriteTo`
    Then no writing error should occur
    And the number of bytes written should match the original input length
    And the written byte sequence should be identical to the original input string

    Examples:
      | input_hcl                                                              |
      | `""`                                                                   | # Empty
      | `foo = 1\n`                                                            | # Simple attribute
      | `\nfoobar = 1\nbaz    = 1\n`                                           | # Aligned attributes
      | `\n# c1\n\n# c2\nfb = 1\nbz = 1\n\nblock {\n a="a"\n}\n# c3\n`          | # Complex with comments and blocks (simplified)

  Scenario Outline: Formatting round trip (Parse, Format, then Evaluate)
    Given an HCL input string:
      """
      <input_hcl>
      """
    And an evaluation context with:
      Variables: `{"hello": StringVal("hello"), "five": NumberIntVal(5)}`
      Functions: `{"upper": stdlib.UpperFunc}`
    When the input string is parsed into an `hclsyntax.File` and its attributes are evaluated to get `values_before`
    Then no parsing or evaluation diagnostics should be reported for `values_before`
    When the original input string is formatted using `hclwrite.Format` to get `formatted_hcl`
    And `formatted_hcl` is parsed into an `hclsyntax.File` and its attributes are evaluated to get `values_after`
    Then no parsing or evaluation diagnostics should be reported for `values_after`
    And `values_after` should be semantically equal to `values_before`

    Examples:
      | input_hcl                                                           |
      | `""`                                                                |
      | `\n\n\n`                                                            |
      | `a=1\n`                                                             |
      | `a="hello"\n`                                                       |
      | `a="${hello} world"\n`                                              |
      | `a=upper("hello")\n`                                                |
      | `a=upper(hello)\n`                                                  |
      | `a=[1,2,3,4,five]\n`                                                |
      | `a={greeting=hello}\n`                                              |
      | `a={\ngreeting=hello,\nnumber=five,\nsarcastic="${upper(hello)}"\n}\n` |
      | `a=<<EOT\nhello\nEOT\n\n`                                           |
      | `a=[\n<<EOT\nhello\nEOT\n]\n`                                       |
      | `a=1\nb=2\nc=3\n`                                                   |
      | `a="${\n5\n}"\n`                                                    |

    # Notes for tables:
    # - Input HCL strings are provided as raw strings, newlines are significant.
    # - The complex example for Verbatim round trip is simplified for brevity.
    # - The evaluation context for Formatting round trip is fixed for all examples in that scenario.
    # - "Semantically equal" means `cty.Value.RawEquals()` returns true.
