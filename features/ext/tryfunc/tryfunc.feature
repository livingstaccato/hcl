# Covers functions in ./ext/tryfunc/tryfunc.go
# Based on test cases in ./ext/tryfunc/tryfunc_test.go

Feature: HCL 'try' and 'can' Functions for Conditional Evaluation
  This feature tests the behavior of the `try` and `can` functions, which allow
  HCL configurations to attempt evaluation of expressions and react to their
  success, failure, or uncertainty (due to unknown values). Both functions
  expect their expression arguments as `customdecode.ExpressionClosureType`.

  Scenario Outline: Evaluating the 'try' function with various expressions
    Given an HCL expression string: `try(<expressions_list_string>)`
    And an evaluation context with variables: <variables_map_json>
    And the `try` function (TryFunc) is available
    When the HCL expression is parsed and evaluated
    Then the resulting cty.Value should be <expected_cty_value_string>
    And if an error is expected, the error message should contain: "<expected_error_substring>"
    And if no error is expected, no error should occur

    Examples:
      | expressions_list_string        | variables_map_json                                     | expected_cty_value_string        | expected_error_substring |
      | `1`                            | {}                                                     | NumberIntVal(1)                  |                          | # One success
      | `sensitive`                    | `{"sensitive": "secret_val(mark:porpoise)"}`           | StringVal("secret_val").Mark("porpoise") |                          | # One marked success
      | `1, 2`                         | {}                                                     | NumberIntVal(1)                  |                          | # Two args, first succeeds
      | `nope, 2`                      | {}                                                     | NumberIntVal(2)                  |                          | # Two args, first fails (nope undefined), second succeeds
      | `unknown, 2`                   | `{"unknown": "?number"}`                               | DynamicVal                       |                          | # First is unknown, try returns dynamic
      | `1, unknown`                   | `{"unknown": "?number"}`                               | NumberIntVal(1)                  |                          | # First succeeds, second unknown is irrelevant
      | `has_unknowns, 2`              | `{"has_unknowns": ["?bool"]}`                          | DynamicVal                       |                          | # First has deep unknown
      | `unknown.baz, 2`               | `{"unknown": "?map(string)"}`                          | DynamicVal                       |                          | # First traverses unknown
      | `sensitive, other`             | `{"sensitive":"s1(m:p)", "other":"s2(m:a)"}`           | StringVal("s1").Mark("p")        |                          | # Both marked, first succeeds
      | `nope, other`                  | `{"other":"s2(m:a)"}`                                  | StringVal("s2").Mark("a")        |                          | # First fails, second marked succeeds
      | `sensitive[0], other`          | `{"sensitive":"[l,o,s](m:secret)", "other":"not_val"}` | StringVal("l").Mark("secret")    |                          | # Result is element of marked list
      | `{u: false ? unknown : "bar"}, other` | `{"unknown":"?string", "other":{"v":"oops"}}`   | ObjectVal({u:StringVal("bar")})  |                          | # Nested known from unknown
      | `{u: unknown["foo"], v:"orig"}, other`| `{"unknown":"?map(string)", "other":{"u":"oops","v":"oops"}}`| DynamicVal                 |                          | # Nested index op on unknown
      | `this, that, particular`       | {}                                                     | NumberIntVal(2)                  | "no expression succeeded"| # All fail (assuming 'this', 'that', 'particular' are undefined, test uses specific error format)
      | ``                             | {}                                                     | NilVal                           | "at least one argument is required" | # No arguments

  Scenario Outline: Evaluating the 'can' function with various expressions
    Given an HCL expression string: `can(<expression_string>)`
    And an evaluation context with variables: <variables_map_json>
    And the `can` function (CanFunc) is available
    When the HCL expression is parsed and evaluated
    Then the resulting cty.Value should be <expected_cty_value_string>
    And no error should occur

    Examples:
      | expression_string | variables_map_json                | expected_cty_value_string |
      | `1`               | {}                                | True                      | # Succeeds
      | `nope`            | {}                                | False                     | # Fails (nope undefined)
      | `unknown`         | `{"unknown": "?number"}`          | UnknownVal(Bool)          | # Simple unknown
      | `unknown.foo`     | `{"unknown": "?map(number)"}`     | UnknownVal(Bool)          | # Traversal through unknown
      | `has_unknown`     | `{"has_unknown": ["?bool"]}`      | UnknownVal(Bool)          | # Deep unknown

    # Notes for tables:
    # - `expressions_list_string`: Comma-separated HCL expressions for `try`.
    # - `variables_map_json`: JSON-like representation of variables.
    #   - `"?type"` e.g., `"?number"` means `cty.UnknownVal(cty.Type)`.
    #   - `"val(m:mark)"` e.g., `"s1(m:p)"` means `cty.StringVal("s1").Mark("p")`.
    #   - `"[v1,v2](m:mark)"` e.g., `"[l,o,s](m:secret)"` means `cty.ListVal([...]).Mark("secret")`.
    # - `expected_cty_value_string`: cty string representation (e.g., `NumberIntVal(1)`, `True`, `DynamicVal`, `UnknownVal(Bool)`).
    # - `expected_error_substring`: A key part of the expected error message if one occurs.
    # - The "All fail" case for `try` has a very specific multi-line error format in the Go test, simplified here.
