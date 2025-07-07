# Covers functions in ./ext/userfunc/public.go and ./ext/userfunc/decode.go
# Based on test cases in ./ext/userfunc/decode_test.go (TestDecodeUserFunctions)

Feature: User-Defined HCL Functions
  This feature tests the `DecodeUserFunctions` capability, allowing users to define
  custom functions within HCL configuration that can then be called in expressions.
  It covers function definition syntax, parameter handling (including variadic),
  result expression evaluation, context/closure behavior, and error handling.

  Scenario Outline: Defining and calling user-defined functions
    Given an HCL configuration string defining functions:
      """
      <hcl_function_definitions>
      """
    And a base `hcl.EvalContext` is prepared <base_context_description>
    And a `ContextFunc` that returns this base context
    When `DecodeUserFunctions` is called with the parsed HCL body, block type "function", and the ContextFunc
    Then the number of diagnostics from decoding functions should be <decode_diag_count>
    And if <decode_diag_count> is 0, a map of functions should be returned.
    When the HCL expression "<test_hcl_expression>" is parsed
    And evaluated with an EvalContext containing the decoded user functions (and the base context for closure tests)
    Then the resulting cty.Value should be <expected_cty_value>
    And the total number of evaluation diagnostics should be <eval_diag_count>

    Examples:
      | hcl_function_definitions                                       | base_context_description         | test_hcl_expression        | decode_diag_count | expected_cty_value                 | eval_diag_count |
      # Basic function
      | `function "greet" { params = ["name"] result = "Hello, ${name}." }` | (nil)                            | `greet("Ermintrude")`      | 0                 | StringVal("Hello, Ermintrude.")  | 0               |
      # Argument errors
      | `function "greet" { params = ["name"] result = "Hello, ${name}." }` | (nil)                            | `greet()`                  | 0                 | DynamicVal                       | 1               | # Missing arg
      | `function "greet" { params = ["name"] result = "Hello, ${name}." }` | (nil)                            | `greet("Ermintrude", "extra")`| 0               | DynamicVal                       | 1               | # Too many args
      # Multiple params
      | `function "add" { params = ["a", "b"] result = a + b }`        | (nil)                            | `add(1, 5)`                | 0                 | NumberIntVal(6)                  | 0               |
      # Variadic params
      | `function "argstuple" { params = [] variadic_param = args result = args }` | (nil)                      | `argstuple("a", true, 1)`  | 0                 | TupleVal([Str("a"),True,Num(1)]) | 0               |
      # Error in result expression
      | `function "missing_var" { params = [] result = nonexist }`     | (nil)                            | `missing_var()`            | 0                 | DynamicVal                       | 1               | # "nonexist" undefined
      # Closure behavior
      | `function "closure" { params = [] result = upvalue }`          | with var "upvalue" = cty.True    | `closure()`                | 0                 | True                             | 0               |
      # Nested calls
      | `function "neg" { params = [val] result = -val } function "add" { params = [a,b] result = a+b }` | (nil) | `neg(add(1, 3))`         | 0                 | NumberIntVal(-4)                 | 0               |
      # Error in function definition itself
      | `function "neg" { parrams = [val] result = -val }` # "parrams" is a typo | (nil)                      | `null` # Test expr doesn't matter | 2                 | NullVal(DynamicPseudoType)       | 0               | # 1 for missing "params", 1 for unknown "parrams". Eval diags for `null` is 0.

    # Notes for table values:
    # - `base_context_description`: Describes the hcl.EvalContext returned by ContextFunc. (nil) means nil context.
    #   "with var 'x' = val" means context has Variables: {"x": val}.
    # - `expected_cty_value`: Simplified cty.Value string representation (e.g., StringVal("text"), True, NumberIntVal(1)).
    # - `decode_diag_count`: Diagnostics from DecodeUserFunctions itself.
    # - `eval_diag_count`: Diagnostics from evaluating the <test_hcl_expression>.
    # - The scenario for "Error in function definition" implies that the `funcs` map might be incomplete or nil if decode_diag_count > 0,
    #   and the subsequent evaluation of `null` is just a way to check this without causing further function call errors. The expected cty.Value
    #   for `null` is indeed `cty.NullVal(cty.DynamicPseudoType)`. The total diags expected are from the decode phase.
