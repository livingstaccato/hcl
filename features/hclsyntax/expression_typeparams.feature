# Covers tests in ./hclsyntax/expression_typeparams_test.go (Go 1.18+ build)
# Specifically, TestExpressionDiagnosticExtra

Feature: HCL Syntax - Expression Diagnostic Extras (Go 1.18+)
  This feature tests the `hcl.DiagnosticExtra` mechanism for function call
  diagnostics, ensuring that specific extra information (like function name,
  namespace, and underlying error) can be retrieved from diagnostics,
  including when the extra information is wrapped. This file is specific
  to Go 1.18+ due to the use of type parameters in `hcl.DiagnosticExtra`.

  Scenario Outline: Retrieving extra information from function call diagnostics
    Given an HCL expression string: "<expression_string>"
    And an evaluation context with functions: <functions_map_json>
    When the expression is parsed and evaluated
    Then diagnostics should be reported
    And the diagnostics should allow retrieval of specific extra information:
      | CheckType             | ExpectedFunctionName | ExpectedNamespace | ExpectedWrappedError |
      | <CheckType1>          | <ExpectedName1>      | <ExpectedNS1>     | <ExpectedError1>     |
      | <CheckType2_Unwrapped>| <ExpectedName2>      | <ExpectedNS2>     | <ExpectedError2>     | # If applicable
      | <CheckType2_Wrapped>  | <ExpectedName2>      | <ExpectedNS2>     | <ExpectedError2>     | # If applicable

    Examples:
      | expression_string  | functions_map_json                        | CheckType1                   | ExpectedName1 | ExpectedNS1 | ExpectedError1     | CheckType2_Unwrapped | ExpectedName2 | ExpectedNS2 | ExpectedError2     | CheckType2_Wrapped |
      | `boop()`           | `{"zap": "returns_dynamic_on_error"}`     | FunctionCallUnknownDiagExtra | "boop"        | ""          |                    |                      |               |             |                    |                    |
      | `ns::source::boop()`| `{"zap": "returns_dynamic_on_error"}`     | FunctionCallUnknownDiagExtra | "boop"        | "ns::source::"|                    |                      |               |             |                    |                    |
      | `boop()`           | `{"boop": "returns_dynamic_on_error"}`    | FunctionCallDiagExtra        | "boop"        |             | "the expected error" | FunctionCallDiagExtra | "boop"      |             | "the expected error" | FunctionCallDiagExtra (Wrapped) | # Second check for wrapped diagnostic

    # Notes for table values:
    # - functions_map_json: Describes functions available in EvalContext.
    #   - "returns_dynamic_on_error": A mock function that returns cty.DynamicVal and a specific error.
    # - CheckType: The Go type to assert for hcl.DiagnosticExtra (e.g., hcl.FunctionCallUnknownDiagExtra, hcl.FunctionCallDiagExtra).
    # - ExpectedFunctionName: The name of the function that was called.
    # - ExpectedNamespace: The namespace of the function, if any (e.g., "ns::source::"). Empty if no namespace.
    # - ExpectedWrappedError: The string representation of the error returned by the function's Impl, if applicable for the CheckType.
    # - "FunctionCallDiagExtra (Wrapped)" means the test first wraps the original diagnostic's Extra field in a custom type that implements hcl.DiagnosticExtraUnwrapper.
    # - This feature file assumes the Go test's logic for constructing mock functions and checking specific fields of the "Extra" data.
