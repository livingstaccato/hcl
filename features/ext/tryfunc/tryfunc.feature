# Covers tests in ./ext/tryfunc/tryfunc_test.go
# Specifically, TestTryFunc and TestCanFunc

Feature: 'try' and 'can' Functions
  This feature tests the behavior of the `try` and `can` functions,
  which are used to gracefully handle expressions that might fail or
  contain unknown values.

  Scenario Outline: Evaluating 'try' function
    Given an HCL expression `<expression>`
    And an evaluation context with variables: <variables>
    And the 'try' function is available
    When the expression is parsed and evaluated
    Then the result should be <expected_value>
    And if an error is expected, it should match: "<expected_error>"
    And if no error is expected, no error should occur

    Examples:
      | expression                               | variables                                           | expected_value          | expected_error                                                                                                                                                                                                                                                                                                                      |
      | `try(1)`                                 | (none)                                              | 1 (number)              |                                                                                                                                                                                                                                                                                                                                         |
      | `try(sensitive)`                         | sensitive = "secret" (marked "porpoise")            | "secret" (marked "porpoise") |                                                                                                                                                                                                                                                                                                                                         |
      | `try(1, 2)`                              | (none)                                              | 1 (number)              |                                                                                                                                                                                                                                                                                                                                         |
      | `try(nope, 2)`                           | (none)                                              | 2 (number)              |                                                                                                                                                                                                                                                                                                                                         |
      | `try(unknown, 2)`                        | unknown = (unknown number)                          | (dynamic)               |                                                                                                                                                                                                                                                                                                                                         |
      | `try(1, unknown)`                        | unknown = (unknown number)                          | 1 (number)              |                                                                                                                                                                                                                                                                                                                                         |
      | `try(has_unknowns, 2)`                   | has_unknowns = [(unknown bool)]                     | (dynamic)               |                                                                                                                                                                                                                                                                                                                                         |
      | `try(unknown.baz, 2)`                    | unknown = (unknown map[string]string)               | (dynamic)               |                                                                                                                                                                                                                                                                                                                                         |
      | `try(sensitive, other)`                  | sensitive = "secret" (marked "porpoise"), other = "that" (marked "a") | "secret" (marked "porpoise") |                                                                                                                                                                                                                                                                                                                         |
      | `try(sensitive, other)`                  | other = "that" (marked "a")                         | "that" (marked "a")     |                                                                                                                                                                                                                                                                                                                                         |
      | `try(sensitive[0], other)`               | sensitive = ["list", "of ", "secrets"] (list marked "secret"), other = "not" | "list" (marked "secret") |                                                                                                                                                                                                                                                                                                                         |
      | `try({u: false ? unknown : "bar"}, other)` | unknown = (unknown string), other = {v:"oops"}      | {u:"bar"} (object)      |                                                                                                                                                                                                                                                                                                                                         |
      | `try({u: unknown["foo"], v: "orig"}, other)` | unknown = (unknown map[string]string), other = {u:"oops", v:"oops"} | (dynamic)            |                                                                                                                                                                                                                                                                                                                         |
      | `try(this, that, this_thing_in_particular)` | (none)                                              | 2 (number)              | test.hcl:1,1-5: Error in function call; Call to function "try" failed: no expression succeeded:...\nAt least one expression must produce a successful result. |
      | `try()`                                  | (none)                                              | (nil)                   | test.hcl:1,1-5: Error in function call; Call to function "try" failed: at least one argument is required.                                                     |

  Scenario Outline: Evaluating 'can' function
    Given an HCL expression `<expression>`
    And an evaluation context with variables: <variables>
    And the 'can' function is available
    When the expression is parsed and evaluated
    Then the result should be <expected_value>
    And no error should occur

    Examples:
      | expression         | variables                             | expected_value    |
      | `can(1)`           | (none)                                | true              |
      | `can(nope)`        | (none)                                | false             |
      | `can(unknown)`     | unknown = (unknown number)            | (unknown bool)    |
      | `can(unknown.foo)` | unknown = (unknown map[string]number) | (unknown bool)    |
      | `can(has_unknown)` | has_unknown = [(unknown bool)]        | (unknown bool)    |

    # Notes:
    # - (none) means no variables are set in the context.
    # - (unknown type) means a cty.UnknownVal of the specified cty.Type.
    # - (dynamic) means cty.DynamicVal.
    # - (nil) means cty.NilVal.
    # - Marks like (marked "porpoise") are cty value marks.
    # - Expected error messages are simplified; the actual error contains more detail.
