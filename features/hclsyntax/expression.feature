# This BDD feature file corresponds to the Go test file:
# ./hclsyntax/expression_test.go
#
# It covers the following Go tests:
# - TestExpressionParseAndValue
# - TestExpressionErrorMessages
# - TestFunctionCallExprValue
# - TestExpressionAsTraversal
# - TestStaticExpressionList
# - TestParseExpression_incompleteFunctionCall
# - TestAllBoolExpressions

Feature: HCL Native Syntax Expression Parsing and Evaluation
  This feature tests the parsing of HCL native syntax expressions and their evaluation
  to cty.Value, including handling of variables, functions, operators, collections,
  control flow constructs (for, conditional), splats, and error reporting.

  Background:
    Given a HCL syntax evaluation context

  Scenario Outline: Evaluating Literal Value Expressions
    Given the HCL expression: "<expression_string>"
    When the expression is parsed and evaluated
    Then the resulting cty.Value should be <expected_cty_value>
    And the number of diagnostics should be <expected_diag_count>

    Examples:
      | expression_string          | expected_cty_value                 | expected_diag_count |
      | `1`                        | NumberIntVal(1)                    | 0                   |
      | `true`                     | True                               | 0                   |
      | `false`                    | False                              | 0                   |
      | `null`                     | NullVal(DynamicPseudoType)         | 0                   |
      | `"hello"`                  | StringVal("hello")                 | 0                   |
      | `"hello\\nworld"`          | StringVal("hello\nworld")          | 0                   |
      | `"<<EOT\nFoo\nEOT\n"`      | StringVal("Foo\n")                 | 0                   | # Simplified heredoc
      | `"hello ${"world"}"`       | StringVal("hello world")           | 0                   |
      | `"silly ${"${"nesting"}"}"` | StringVal("silly nesting")         | 0                   |
      | `"hello $${escaped}"`      | StringVal("hello ${escaped}")      | 0                   |
      # Error cases for literals
      | `"unclosed`                | StringVal("unclosed")              | 1                   | # Unterminated string

  Scenario Outline: Evaluating Arithmetic Operations
    Given the HCL expression: "<expression_string>"
    And an evaluation context with variables: <variables_json>
    When the expression is parsed and evaluated
    Then the resulting cty.Value should be <expected_cty_value>
    And the number of diagnostics should be <expected_diag_count>

    Examples:
      | expression_string | variables_json                   | expected_cty_value      | expected_diag_count |
      | `(2+3)`           | {}                               | NumberIntVal(5)         | 0                   |
      | `2*5+1`           | {}                               | NumberIntVal(11)        | 0                   |
      | `9%8`             | {}                               | NumberIntVal(1)         | 0                   |
      | `(- 2)`           | {}                               | NumberIntVal(-2)        | 0                   |
      | `(2+unk)`         | `{"unk": "?number(not_null)"}`   | UnknownVal(Number).RefineNotNull() | 0      |
      | `(2+unk)`         | `{"unk": "dynamic"}`             | UnknownVal(Number).RefineNotNull() | 0      |
      | `(2+true)`        | {}                               | UnknownVal(Number)      | 1                   | # Unsuitable type for right
      | `(false+true)`    | {}                               | UnknownVal(Number)      | 2                   | # Unsuitable types

  Scenario Outline: Evaluating Comparison Operations
    Given the HCL expression: "<expression_string>"
    When the expression is parsed and evaluated
    Then the resulting cty.Value should be <expected_cty_value>
    And the number of diagnostics should be <expected_diag_count>

    Examples:
      | expression_string  | expected_cty_value | expected_diag_count |
      | `(5 == 5)`         | True               | 0                   |
      | `(5 == 4)`         | False              | 0                   |
      | `(1 == true)`      | False              | 0                   | # cty specific comparison rules
      | `("true" == true)` | False              | 0                   |
      | `(true != "true")` | True               | 0                   |

  Scenario Outline: Evaluating Logical Operations (including short-circuiting)
    Given the HCL expression: "<expression_string>"
    And an evaluation context with variables: <variables_json>
    When the expression is parsed and evaluated
    Then the resulting cty.Value should be <expected_cty_value>
    And the number of diagnostics should be <expected_diag_count>

    Examples:
      # Basic
      | expression_string        | variables_json                                      | expected_cty_value                 | expected_diag_count |
      | `(! true)`               | {}                                                  | False                              | 0                   |
      # Short-circuiting AND
      | `false && missing_var`   | {}                                                  | False                              | 0                   |
      | `true && true`           | {}                                                  | True                               | 0                   |
      | `true && unknown_bool`   | `{"unknown_bool": "?bool(not_null)"}`               | UnknownVal(Bool).RefineNotNull()   | 0                   |
      | `unknown_bool && false`  | `{"unknown_bool": "?bool(not_null)"}`               | False                              | 0                   |
      # Short-circuiting OR
      | `true || missing_var`    | {}                                                  | True                               | 0                   |
      | `false || false`         | {}                                                  | False                              | 0                   |
      | `false || unknown_bool`  | `{"unknown_bool": "?bool(not_null)"}`               | UnknownVal(Bool).RefineNotNull()   | 0                   |
      | `unknown_bool || true`   | `{"unknown_bool": "?bool(not_null)"}`               | True                               | 0                   |
      # Error propagation even with short-circuit value
      | `foo(value) && false`    | {}                                                  | False                              | 0                   | # foo() not called
      | `foo(value) && true`     | {}                                                  | UnknownVal(Bool).RefineNotNull()   | 1                   | # foo() called and fails
      # Marked value propagation
      | `lhsFalse && rhsUnknown` | `{"lhsFalse":"false(m:a)", "rhsUnknown":"?bool(m:b)"}` | False.Mark("a").Mark("b")          | 0                   |

  Scenario Outline: Evaluating Conditional Expressions
    Given the HCL expression: "<expression_string>"
    And an evaluation context with variables: <variables_json>
    When the expression is parsed and evaluated
    Then the resulting cty.Value should be <expected_cty_value>
    And the number of diagnostics should be <expected_diag_count>
    And if a specific error summary is expected, it should be "<expected_error_summary>"

    Examples:
      | expression_string   | variables_json                               | expected_cty_value                                     | expected_diag_count | expected_error_summary                 |
      | `true ? 1 : 0`      | {}                                           | NumberIntVal(1)                                        | 0                   |                                        |
      | `false ? 1 : 0`     | {}                                           | NumberIntVal(0)                                        | 0                   |                                        |
      | `true ? ["a"] : null` | {}                                           | TupleVal([StringVal("a")])                             | 0                   |                                        |
      | `false ? null : ["a"]`| {}                                           | TupleVal([StringVal("a")])                             | 0                   |                                        |
      | `unknown ? 1 : 0`   | `{"unknown": "?bool"}`                       | UnknownVal(Number).RefineNotNull().NumberRange(0,1)    | 0                   |                                        | # Type unification and refinement
      | `true ? 1 : true`   | {}                                           | DynamicVal                                             | 1                   | Inconsistent conditional result types  |
      | `marked_cond ? 1 : 0`| `{"marked_cond": "true(m:sensitive)"}`      | NumberIntVal(1).Mark("sensitive")                      | 0                   |                                        |

  Scenario Outline: Evaluating Collection Constructors (Tuples and Objects)
    Given the HCL expression: "<expression_string>"
    And an evaluation context with variables: <variables_json>
    When the expression is parsed and evaluated
    Then the resulting cty.Value should be <expected_cty_value>
    And the number of diagnostics should be <expected_diag_count>

    Examples:
      # Tuples
      | expression_string | variables_json | expected_cty_value                       | expected_diag_count |
      | `[]`              | {}             | EmptyTupleVal                            | 0                   |
      | `[1]`             | {}             | TupleVal([NumberIntVal(1)])              | 0                   |
      | `[1,]`            | {}             | TupleVal([NumberIntVal(1)])              | 0                   |
      | `[1,true]`        | {}             | TupleVal([NumberIntVal(1), True])        | 0                   |
      # Objects
      | `{}`                       | {}             | EmptyObjectVal                           | 0                   |
      | `{"hello": "world"}`       | {}             | ObjectVal({"hello": StringVal("world")}) | 0                   |
      | `{hello = "world"}`        | {}             | ObjectVal({"hello": StringVal("world")}) | 0                   |
      | `{hello: "world"}`         | {}             | ObjectVal({"hello": StringVal("world")}) | 0                   |
      | `{true: "yes"}`            | {}             | ObjectVal({"true": StringVal("yes")})    | 0                   |
      | `{foo.bar = "val"}`        | {}             | DynamicVal                               | 1                   | # Ambiguous key
      | `{(var.key) = "val"}`      | `{"var":{"key":"actual_key"}}` | ObjectVal({"actual_key": StringVal("val")}) | 0  |
      | `{"${var.key}" = "val"}`   | `{"var":{"key":"actual_key"}}` | ObjectVal({"actual_key": StringVal("val")}) | 0  |
      | `{(var.mkey) = "val"}`     | `{"var":{"mkey":"actual_key(m:foo)"}}` | ObjectVal({"actual_key": StringVal("val")}).Mark("foo") | 0  |

  Scenario Outline: Evaluating Variable and Attribute/Index Access
    Given the HCL expression: "<expression_string>"
    And an evaluation context with variables: <variables_json>
    When the expression is parsed and evaluated
    Then the resulting cty.Value should be <expected_cty_value>
    And the number of diagnostics should be <expected_diag_count>

    Examples:
      | expression_string | variables_json                                        | expected_cty_value        | expected_diag_count |
      | `foo`             | `{"foo": "hello_val"}`                                | StringVal("hello_val")    | 0                   |
      | `bar`             | `{}`                                                  | DynamicVal                | 1                   | # Unknown variable
      | `foo.baz`         | `{"foo": {"baz": "nested_val"}}`                      | StringVal("nested_val")   | 0                   |
      | `foo.missing`     | `{"foo": {"baz": "nested_val"}}`                      | DynamicVal                | 1                   | # Missing attribute
      | `foo["baz"]`      | `{"foo": {"baz": "nested_val"}}`                      | StringVal("nested_val")   | 0                   |
      | `list[0]`         | `{"list": ["first_val"]}`                             | StringVal("first_val")    | 0                   |
      | `list[1]`         | `{"list": ["first_val"]}`                             | DynamicVal                | 1                   | # Index out of bounds
      | `unk_str["idx"]`  | `{"unk_str": "?string"}`                              | DynamicVal                | 1                   | # String has no indices
      | `unk_map["key"]`  | `{"unk_map": "?map(string)"}`                         | UnknownVal(String)        | 0                   |

  Scenario Outline: Evaluating Function Calls
    Given the HCL expression: "<expression_string>"
    And an evaluation context with functions: <functions_setup> and variables: <variables_json>
    When the expression is parsed and evaluated
    Then the resulting cty.Value should be <expected_cty_value>
    And the number of diagnostics should be <expected_diag_count>

    Examples:
      | expression_string        | functions_setup        | variables_json | expected_cty_value      | expected_diag_count |
      | `upper("foo")`           | `{"upper": "stdlib_upper"}` | {}             | StringVal("FOO")        | 0                   |
      | `upper(["foo"]...)`      | `{"upper": "stdlib_upper"}` | {}             | StringVal("FOO")        | 0                   |
      | `upper("foo", "bar")`    | `{"upper": "stdlib_upper"}` | {}             | DynamicVal              | 1                   | # Too many args
      | `ns::upper("foo")`       | `{"ns::upper": "stdlib_upper"}` | {}         | StringVal("FOO")        | 0                   |
      | `missing_func()`         | `{}`                       | {}             | DynamicVal              | 1                   | # Unknown function
      | `jsondecode(unk_str)`    | `{"jsondecode":"stdlib_jsondecode"}` | `{"unk_str":"?string"}` | DynamicVal | 0                  | # Dynamic return type
      | `min(marked_list...)`    | `{"min":"stdlib_min"}`     | `{"marked_list":"[3,1,4](m:sens)"}` | NumberIntVal(1).Mark("sens") | 0 |

  Scenario Outline: Evaluating For Expressions (Tuple and Object)
    Given the HCL expression: "<expression_string>"
    And an evaluation context with variables: <variables_json> and functions: <functions_setup>
    When the expression is parsed and evaluated
    Then the resulting cty.Value should be <expected_cty_value>
    And the number of diagnostics should be <expected_diag_count>

    Examples:
      # Tuple For
      | expression_string                             | variables_json                  | functions_setup        | expected_cty_value                           | expected_diag_count |
      | `[for v in ["a", "b"]: upper(v)]`             | {}                              | `{"upper":"stdlib_upper"}` | TupleVal([StringVal("A"), StringVal("B")])    | 0                   |
      | `[for i,v in ["a","b"]: "${i}-${v}" if i==0]` | {}                              | {}                     | TupleVal([StringVal("0-a")])                 | 0                   |
      | `[for v in unk_list: v]`                      | `{"unk_list": "?list(string)"}` | {}                     | DynamicVal                                   | 0                   |
      | `[for v in ["a"]: v if unk_bool]`             | `{"unk_bool": "?bool"}`          | {}                     | DynamicVal                                   | 0                   |
      | `[for x in marked_list: x]`                   | `{"marked_list": "[\"a\"](m:s)"}` | {}                     | TupleVal([StringVal("a")]).Mark("s")         | 0                   |
      # Object For
      | `{for k,v in {a="b"}: upper(k) => upper(v)}`  | {}                              | `{"upper":"stdlib_upper"}` | ObjectVal({"A": StringVal("B")})             | 0                   |
      | `{for v in ["x"]: v => v}`                    | {}                              | {}                     | ObjectVal({"x": StringVal("x")})             | 0                   |
      | `{for k,v in {a="b"}: k => v if k=="z"}`      | {}                              | {}                     | EmptyObjectVal                               | 0                   |
      | `{for i,v in ["a","b","a"]: v => i...}`       | {}                              | {}                     | ObjectVal({"a":TupleVal([Num(0),Num(2)]), "b":TupleVal([Num(1)])}) | 0 |
      | `{for v in marked_map: v => upper(v)}`        | `{"marked_map": "{\"k\":\"v\"}(m:s)"}` |`{"upper":"stdlib_upper"}`| ObjectVal({"k":StringVal("V")}).Mark("s") | 0                   |

  Scenario Outline: Evaluating Splat Expressions
    Given the HCL expression: "<expression_string>"
    And an evaluation context with variables: <variables_json>
    When the expression is parsed and evaluated
    Then the resulting cty.Value should be <expected_cty_value>
    And the number of diagnostics should be <expected_diag_count>

    Examples:
      | expression_string                               | variables_json                                       | expected_cty_value                                    | expected_diag_count |
      | `[{name:"S"}, {name:"E"}].*.name`               | {}                                                   | TupleVal([StringVal("S"), StringVal("E")])           | 0                   |
      | `{name:"S"}.*.name`                             | {}                                                   | TupleVal([StringVal("S")])                            | 0                   |
      | `null[*]`                                       | {}                                                   | EmptyTupleVal                                         | 0                   |
      | `{name:"S"}[*].name`                            | {}                                                   | TupleVal([StringVal("S")])                            | 0                   |
      | `unk_list_obj.*.name`                           | `{"unk_list_obj": "?list(object({name=string}))"}`    | UnknownVal(List(String)).RefineNotNull()              | 0                   |
      | `[["h"], ["w", "u"]].*.0`                       | {}                                                   | TupleVal([StringVal("h"), StringVal("w")])           | 0                   |
      | `marked_list.*.name`                            | `{"marked_list": "[{name=\"A\"}](m:s)"}`             | ListVal([StringVal("A")]).Mark("s")                   | 0                   |

  Scenario: Expression to Traversal Conversion
    Given the HCL expression `a.b[0]["c"]`
    When `hcl.AbsTraversalForExpr` is called on the parsed expression
    Then the resulting traversal should be `["a", "b", cty.NumberIntVal(0), cty.StringVal("c")]`
    And no diagnostics should be reported

  Scenario: Extracting Expression List from Tuple Literal
    Given the HCL expression `[0, var_a, true]`
    And an evaluation context where "var_a" is a variable
    When `hcl.ExprList` is called on the parsed expression
    Then the result should be a list of 3 expressions
    And the first expression should be a LiteralValueExpr for cty.Zero
    And the second expression should be a ScopeTraversalExpr for "var_a"
    And the third expression should be a LiteralValueExpr for cty.True
    And no diagnostics should be reported

  Scenario Outline: Parsing incomplete function calls and range reporting
    Given the HCL expression representing an incomplete function call: "<expression_string>"
    When the expression is parsed with filename "test.hcl"
    Then the expression's `Range().End` should be at Line <end_line>, Column <end_col>, Byte <end_byte>
      # Start is assumed hcl.InitialPos for these test cases

    Examples:
      | expression_string | end_line | end_col | end_byte |
      | `object({ foo = })` | 1        | 18      | 17       |
      | `object({\n  foo = \n})` | 3        | 3       | 19       |
      # Examples where parser recovery might lead to Zero range if not handled
      | `object({ foo = }`    | 0        | 0       | 0        | # Test case implies specific recovery behavior
      | `object({\n  foo =\n` | 0        | 0       | 0        | # Test case implies specific recovery behavior

    # Notes for table values:
    # - `?type` (e.g. `?number`) means `cty.UnknownVal(cty.Type)`. `?type(not_null)` means it's also refined as NotNull.
    # - `dynamic` means `cty.DynamicVal`.
    # - `"val(m:mark)"` means `cty.StringVal("val").Mark("mark")`. `[val1,val2](m:mark)` for collections.
    # - `NumberRange(min,max)` is a simplified representation of number refinements.
    # - `functions_setup`: JSON-like map, e.g., `{"upper": "stdlib_upper"}`. Step defs map to actual funcs.
    # - `expected_cty_value` uses cty package style names (e.g., `NumberIntVal`, `True`, `StringVal`, `TupleVal`, `ObjectVal`, `EmptyTupleVal`, `EmptyObjectVal`, `NullVal`, `UnknownVal`, `DynamicVal`).
    # - For the "incomplete function call" ranges, the Go test has specific expectations for how far the parser successfully parses.
    #   A result of Line 0, Col 0, Byte 0 usually indicates the parser bailed out very early or the range was not determined.
    #   The original test cases for these seem to expect specific non-zero end positions for some, and zero for others, likely due to recovery.
    #   The BDD reflects the values from the Go test's `expectedRange`.
```
