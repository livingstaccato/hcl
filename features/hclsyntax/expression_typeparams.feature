# This BDD feature file corresponds to the Go test file:
# ./hclsyntax/expression_typeparams_test.go
#
# While the Go test file is build-tagged for Go 1.18+, the BDD scenarios
# describe HCL diagnostic behaviors that are generally applicable.
# This feature focuses on the detailed "Extra" information provided in diagnostics
# related to HCL expression function calls.

Feature: HCL Expression Function Call Diagnostic Details
  This feature tests that diagnostics generated during HCL expression evaluation,
  specifically for function call issues, provide rich contextual "Extra" information.

  Background:
    Given an HCL syntax evaluation context

  Scenario Outline: Diagnostic details for unknown function calls
    Given an HCL expression calling a function: "<hcl_expression>"
    And the evaluation context has functions defined as: <defined_functions_json>
      # e.g., {"zap": "some_function_def"} or {} if none relevant
    When the HCL expression is parsed and evaluated
    Then at least one error diagnostic should be reported
    And one of the error diagnostics should provide `FunctionCallUnknownDiagExtra` information
    And this extra information should report the called function name as "<expected_function_name>"
    And this extra information should report the called function namespace as "<expected_namespace>"

    Examples:
      | hcl_expression     | defined_functions_json | expected_function_name | expected_namespace |
      | `boop()`             | `{"zap": "exists"}`    | "boop"                 | ""                 |
      | `ns::source::boop()` | `{"zap": "exists"}`    | "boop"                 | "ns::source::"     |

  Scenario: Diagnostic details for errors occurring within a function call
    Given an HCL expression calling a function: `error_func()`
    And the function "error_func" is defined in the evaluation context
    And the implementation of "error_func" will return an error with message "internal function error"
    When the HCL expression `error_func()` is parsed and evaluated
    Then at least one error diagnostic should be reported
    And one of the error diagnostics should provide `FunctionCallDiagExtra` information
    And this extra information should report the called function name as "error_func"
    And the `FunctionCallError()` from this extra information should be an error with message "internal function error"

  Scenario: Accessing diagnostic extra information through unwrapping
    Given a diagnostic related to a function call error (e.g., from calling `error_func()`)
    And its `Extra` field is wrapped by a custom type that implements `hcl.DiagnosticExtraUnwrapper`
      # The wrapper contains the original FunctionCallDiagExtra
    When `hcl.DiagnosticExtra[FunctionCallDiagExtra]` is used to retrieve the typed extra data from the diagnostic
    Then the retrieval should be successful
    And the retrieved data should be the underlying `FunctionCallDiagExtra` instance
    And its `CalledFunctionName()` should be "error_func"
    And its `FunctionCallError()` should reflect the "internal function error"

    # Notes for table values:
    # - `<defined_functions_json>`: A simplified representation of the functions available in the EvalContext.
    #   The actual function definitions are set up in step definitions to match test conditions.
    # - The "unwrapping" scenario is more about the HCL diagnostic framework's capability but is
    #   tested in conjunction with expression evaluation diagnostics in the Go test.
```
