# Covers tests in ./diagnostic_text_test.go
# Specifically, TestDiagnosticTextWriter

Feature: HCL Diagnostic Text Writer
  This feature tests the functionality of `NewDiagnosticTextWriter` for formatting
  HCL diagnostics into human-readable text, including source code snippets,
  context information, and relevant variable values.

  Background:
    Given a source file content:
      """
      foo = 1
      bar = 2
      baz = 3
      block "party" {
        pizza = "cheese"
      }
      """
    And a map of files where the empty string key maps to this file content.
    And a diagnostic text writer configured with a width of 40 characters and color disabled.

  Scenario Outline: Formatting various HCL diagnostics
    Given an HCL Diagnostic with:
      Severity: <Severity>
      Summary: "<Summary>"
      Detail: "<Detail>"
      Subject Range: <Subject>
      Context Range: <Context>
      Expression: <ExpressionDetails>
      EvalContext: <EvalContextDetails>
    When the diagnostic is written using the diagnostic text writer
    Then the output should be:
      """
      <ExpectedOutput>
      """

    Examples:
      | Severity | Summary                   | Detail                                  | Subject          | Context          | ExpressionDetails | EvalContextDetails | ExpectedOutput                                                                                                                               |
      | Error    | Splines not reticulated   | All splines must be pre-reticulated.    | L1C1-L1C4 (B0-B3) | (nil)            | (nil)             | (nil)              | Error: Splines not reticulated\n\n  on  line 1, in hardcoded-context:\n   1: foo = 1\n\nAll splines must be pre-reticulated.\n\n                 |
      | Error    | Unsupported attribute     | "baz" is not a supported top-level attribute. Did you mean "bam"? | L3C1-L3C4 (B16-B19) | (nil)            | (nil)             | (nil)              | Error: Unsupported attribute\n\n  on  line 3, in hardcoded-context:\n   3: baz = 3\n\n"baz" is not a supported top-level\nattribute. Did you mean "bam"?\n\n |
      | Error    | Unsupported attribute     | "pizza" is not a supported attribute. Did you mean "pizzetta"? | L5C3-L5C8 (B42-B47) | L4C1-L6C2 (B24-B60) | (nil)             | (nil)              | Error: Unsupported attribute\n\n  on  line 5, in hardcoded-context:\n   4: block "party" {\n   5:   pizza = "cheese"\n   6: }\n\n"pizza" is not a supported attribute.\nDid you mean "pizzetta"?\n\n |
      | Error    | Test of including relevant variable values | This diagnostic includes an expression and an evalcontext. | L5C3-L5C8 (B42-B47) | (nil)            | vars:[foo, bar.baz, missing, boz] | {parent:{foo:"foo value"}, self:{bar.baz:[], boz:5, unused:true}} | Error: Test of including relevant variable values\n\n  on  line 5, in hardcoded-context:\n   5:   pizza = "cheese"\n\nwith bar.baz as empty list of string,\n     boz as 5,\n     foo as "foo value".\n\nThis diagnostic includes an expression\nand an evalcontext.\n\n |

    # Notes on table values:
    # - Ranges like L1C1-L1C4 (B0-B3) mean Line 1, Column 1 to Line 1, Column 4 (Byte 0 to Byte 3).
    # - (nil) means the corresponding field in the Diagnostic struct is nil.
    # - ExpressionDetails: "vars:[foo, bar.baz, missing, boz]" means the mock expression returns these traversals.
    # - EvalContextDetails: "{parent:{foo:"foo value"}, self:{bar.baz:[], boz:5, unused:true}}" describes a nested EvalContext.
    #   "bar.baz:[]" means cty.ListValEmpty(cty.String).
    # - The context string "hardcoded-context" comes from a mock navigator.
    # - Output formatting (line breaks, indentation) must match exactly.
