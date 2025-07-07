# Covers hcl.NewDiagnosticTextWriter and its WriteDiagnostic method in ./diagnostic_text.go
# Based on test cases in ./diagnostic_text_test.go (TestDiagnosticTextWriter)

Feature: HCL Diagnostic Text Formatting
  This feature tests the `NewDiagnosticTextWriter` for its ability to format
  `hcl.Diagnostic` objects into human-readable text, including severity, summary,
  detail, source code snippets with highlighting, and relevant variable values
  from an evaluation context.

  Background:
    Given a source file named "" (empty string for default) with content:
      """
      foo = 1
      bar = 2
      baz = 3
      block "party" {
        pizza = "cheese"
      }
      """
    And a map of `hcl.File` objects containing this file, associated with a mock navigator that returns "hardcoded-context" for any offset
    And a `DiagnosticTextWriter` is created with this file map, a target width of 40, and color output disabled

  Scenario Outline: Formatting an HCL Diagnostic into text
    Given an `hcl.Diagnostic` with the following properties:
      Severity: <Severity>
      Summary: "<Summary>"
      Detail: "<Detail>"
      Subject: Range(<SubjectRangeStr>)
      Context: Range(<ContextRangeStr>)
      Expression: <ExpressionDetails>
      EvalContext: <EvalContextDetails>
    When the diagnostic is written using the `DiagnosticTextWriter`
    Then no writing error should occur
    And the formatted output string should be exactly:
      """
      <ExpectedOutput>
      """

    Examples:
      | Severity  | Summary                   | Detail                                  | SubjectRangeStr     | ContextRangeStr     | ExpressionDetails                 | EvalContextDetails | ExpectedOutput                                                                                                                                                                                                                                                                                         |
      | DiagError | Splines not reticulated   | All splines must be pre-reticulated.    | L1C1B0-L1C4B3       | (nil)               | (nil)                             | (nil)              | Error: Splines not reticulated\n\n  on  line 1, in hardcoded-context:\n   1: foo = 1\n\nAll splines must be pre-reticulated.\n\n                                                                                                                                                                 |
      | DiagError | Unsupported attribute     | "baz" is not a supported top-level attribute. Did you mean "bam"? | L3C1B16-L3C4B19     | (nil)               | (nil)                             | (nil)              | Error: Unsupported attribute\n\n  on  line 3, in hardcoded-context:\n   3: baz = 3\n\n"baz" is not a supported top-level\nattribute. Did you mean "bam"?\n\n                                                                                                                               |
      | DiagError | Unsupported attribute     | "pizza" is not a supported attribute. Did you mean "pizzetta"? | L5C3B42-L5C8B47     | L4C1B24-L6C2B60     | (nil)                             | (nil)              | Error: Unsupported attribute\n\n  on  line 5, in hardcoded-context:\n   4: block "party" {\n   5:   pizza = "cheese"\n   6: }\n\n"pizza" is not a supported attribute.\nDid you mean "pizzetta"?\n\n                                                                                                                |
      | DiagError | Test of including relevant variable values | This diagnostic includes an expression and an evalcontext. | L5C3B42-L5C8B47     | (nil)               | Vars:[foo, bar.baz, missing, boz] | Ctx:{p:{foo:"foo val"}, s:{bar.baz:[], boz:5}} | Error: Test of including relevant variable values\n\n  on  line 5, in hardcoded-context:\n   5:   pizza = "cheese"\n\nwith bar.baz as empty list of string,\n     boz as 5,\n     foo as "foo value".\n\nThis diagnostic includes an expression\nand an evalcontext.\n\n |

    # Notes for table values:
    # - Range(<RangeStr>): Describes an hcl.Range. L1C1B0-L1C4B3 means Line 1, Col 1, Byte 0 to Line 1, Col 4, Byte 3. (nil) means the range is not set.
    # - ExpressionDetails: Vars:[...] lists root names of traversals returned by a mock Expression.Variables(). (nil) means no expression.
    # - EvalContextDetails: Ctx:{p:{vars}, s:{vars}} describes a context with self 's' and parent 'p' variables.
    #   - `foo:"foo val"` means variable "foo" is cty.StringVal("foo value").
    #   - `bar.baz:[]` means variable "bar" is an object with attribute "baz" as cty.ListValEmpty(cty.String).
    #   - `boz:5` means variable "boz" is cty.NumberIntVal(5).
    # - The ExpectedOutput is an exact string match, including newlines and spacing.
    # - The "hardcoded-context" comes from a mock navigator used in the Go test.
