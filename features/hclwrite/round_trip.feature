# This BDD feature file corresponds to the Go test file:
# ./hclwrite/round_trip_test.go
#
# It covers the following Go tests:
# - TestRoundTripVerbatim
# - TestRoundTripFormat
# - TestRoundTripSafeConcurrent

Feature: HCL Write Round Trip Integrity
  This feature ensures that HCL content, when parsed by `hclwrite` and then
  written out, maintains its original structure and comments (verbatim round trip)
  or its semantic meaning (format round trip). It also touches upon concurrency safety.

  Background:
    Given a HCL writing context

  Scenario Outline: Verbatim Round Trip - Parsing and Writing Preserves Bytes
    The `hclwrite` parser and writer should preserve the exact byte sequence,
    including comments and whitespace, when no explicit formatting is applied.

    Given the HCL input string:
      """
      <hcl_input_verbatim>
      """
    When this input is parsed by `hclwrite`'s internal parser into a file object
    And the file object is written back to bytes using `WriteTo`
    Then the output byte sequence should be identical to the original input string
    And no parsing or writing diagnostics should be reported

    Examples:
      | hcl_input_verbatim                                     |
      | ``                                                     |
      | `foo = 1\n`                                            |
      | `\nfoobar = 1\nbaz    = 1\n`                           |
      | `\n# c1\n\n# c2\nfb = 1\nbz = 1\n\nblock {\n  a = "a"\n}\n# c3\n` | # Simplified complex example

  Scenario Outline: Format Round Trip - Formatting Preserves Semantic Meaning
    The `hclwrite.Format` function, while altering whitespace, must not change
    the semantic meaning of the HCL configuration. This is verified by evaluating
    attributes before and after formatting.

    Given the HCL input string:
      """
      <hcl_input_for_formatting>
      """
    And an evaluation context with variables: <variables_json> and functions: <functions_json>
      # e.g., variables_json: `{"hello":"world", "five":5}`
      # e.g., functions_json: `{"upper":"stdlib_upper"}`
    When the attributes from the original input are parsed and evaluated to get "original_values"
    And the input string is formatted using `hclwrite.Format` to get "formatted_hcl"
    And the attributes from the "formatted_hcl" are parsed and evaluated using the same context to get "formatted_values"
    Then "original_values" should be semantically equal to "formatted_values" (cty.Value RawEquals)
    And no parsing or evaluation diagnostics should occur for either version

    Examples:
      | hcl_input_for_formatting                                       | variables_json                     | functions_json               |
      | ``                                                             | {}                                 | {}                           |
      | `a=1\n`                                                        | {}                                 | {}                           |
      | `a="hello"\n`                                                  | {}                                 | {}                           |
      | `a="${hello} world"\n`                                         | `{"hello":"hi"}`                   | {}                           |
      | `a=upper("hello")\n`                                           | {}                                 | `{"upper":"stdlib_upper"}`   |
      | `a=upper(hello)\n`                                             | `{"hello":"val"}`                  | `{"upper":"stdlib_upper"}`   |
      | `a=[1,2,3,five]\n`                                             | `{"five":5}`                       | {}                           |
      | `a={greeting=hello}\n`                                         | `{"hello":"hi"}`                   | {}                           |
      | `a={\ngreeting=hello,\nnumber=five,\nsarcastic="${upper(hello)}"}\n` | `{"hello":"hi","five":5}`        | `{"upper":"stdlib_upper"}`   |
      | `a=<<EOT\nhello\nEOT\n\n`                                      | {}                                 | {}                           |
      | `a=[<<EOT\nhello\nEOT\n]\n`                                    | {}                                 | {}                           |
      | `a=1\nb=2\nc=3\n`                                              | {}                                 | {}                           |
      | `a="${\n5\n}"\n`                                               | {}                                 | {}                           |

  Scenario: Concurrency safety for hclwrite File operations
    When multiple operations concurrently create new `hclwrite.File` objects
    And concurrently modify these files (e.g., by calling `Body().SetAttributeValue()`)
    Then these operations should complete without data races or panics related to concurrent access.
    # This property is typically verified using Go's race detector during testing.
    # The BDD scenario describes the expected safe behavior.
```
