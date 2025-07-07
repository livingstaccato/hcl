# Covers tests in ./ext/userfunc/decode_test.go
# Specifically, TestDecodeUserFunctions

Feature: User-Defined Function Decoding and Execution
  This feature tests the decoding of HCL `function` blocks and the subsequent
  execution of these user-defined functions within HCL expressions.

  Scenario Outline: Defining and calling user functions
    Given an HCL configuration defining functions:
      """
      <function_definitions>
      """
    And a base evaluation context <base_context_setup>
    When the user functions are decoded from the configuration
    And the HCL expression `<test_expression>` is parsed
    And the parsed expression is evaluated using the decoded user functions
    Then the resulting value should be <expected_value>
    And the total number of diagnostics (from function decoding and expression evaluation) should be <diagnostics_count>

    Examples:
      | function_definitions                                       | test_expression        | base_context_setup             | expected_value                 | diagnostics_count |
      | function "greet" { params = [name] result = "Hello, ${name}." } | greet("Ermintrude")    | (none)                         | "Hello, Ermintrude."           | 0                 |
      | function "greet" { params = [name] result = "Hello, ${name}." } | greet()                | (none)                         | (dynamic)                      | 1                 |
      | function "greet" { params = [name] result = "Hello, ${name}." } | greet("Ermintrude", "extra") | (none)                   | (dynamic)                      | 1                 |
      | function "add" { params = [a, b] result = a + b }            | add(1, 5)              | (none)                         | 6                              | 0                 |
      | function "argstuple" { params = [] variadic_param = args result = args } | argstuple("a", true, 1) | (none)                    | ["a", true, 1] (tuple)         | 0                 |
      | function "missing_var" { params = [] result = nonexist }     | missing_var()          | (none)                         | (dynamic)                      | 1                 |
      | function "closure" { params = [] result = upvalue }          | closure()              | with variable "upvalue" = true | true                           | 0                 |
      | function "neg" { params = [val] result = -val } function "add" { params = [a, b] result = a + b } | neg(add(1, 3))         | (none)                         | -4                             | 0                 |
      | function "neg" { parrams = [val] result = -val } # Typo in params | null                   | (none)                         | (null dynamic)                 | 2                 |

    # Notes:
    # - <base_context_setup> describes how the hcl.EvalContext provided to decodeUserFunctions is set up.
    # - "(dynamic)" represents cty.DynamicVal.
    # - "(null dynamic)" represents cty.NullVal(cty.DynamicPseudoType).
    # - "(tuple)" indicates a cty.TupleVal.
