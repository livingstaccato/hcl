# Covers tests in ./hclsyntax/expression_test.go
# Specifically, TestExpressionParseAndValue, TestExpressionErrorMessages,
# TestFunctionCallExprValue, TestExpressionAsTraversal, TestStaticExpressionList,
# TestParseExpression_incompleteFunctionCall, and TestAllBoolExpressions.

Feature: HCL Syntax - Expression Parsing and Evaluation
  This feature tests the parsing of various HCL expressions and their evaluation
  to `cty.Value` objects. It covers literals, arithmetic operations, comparisons,
  logical operations, function calls, template expressions, collection constructors
  (tuples, objects), 'for' expressions, splat expressions, and indexing.
  It also verifies diagnostic reporting for syntax errors and evaluation errors,
  and correct handling of unknown/dynamic values and cty marks.

  Scenario Outline: Parsing and evaluating HCL expressions
    Given an HCL expression string: "<expression_string>"
    And an evaluation context:
      | type      | details                                       |
      | variables | <variables_map_json>                          |
      | functions | <functions_list>                              |
    When the expression string is parsed
    And the parsed expression is evaluated with the context
    Then the number of total diagnostics (parse + eval) should be <diagnostics_count>
    And the resulting cty.Value should be <expected_cty_value_string>

    Examples:
      # Literals and Basic Ops
      | expression_string        | variables_map_json | functions_list | diagnostics_count | expected_cty_value_string        |
      | `1`                      | {}                 | []             | 0                 | NumberIntVal(1)                  |
      | `(2+3)`                  | {}                 | []             | 0                 | NumberIntVal(5)                  |
      | `2*5+1`                  | {}                 | []             | 0                 | NumberIntVal(11)                 |
      | `9%8`                    | {}                 | []             | 0                 | NumberIntVal(1)                  |
      | `(2+unk)`                | `{"unk":"?"}`      | []             | 0                 | UnknownVal(Number).NotNull()     | # unk is cty.UnknownVal(cty.Number)
      | `(2+true)`               | {}                 | []             | 1                 | UnknownVal(Number)               | # unsuitable type for right operand
      | `(5 == 5)`               | {}                 | []             | 0                 | True                             |
      | `(1 == true)`            | {}                 | []             | 0                 | False                            |
      | `(- 2)`                  | {}                 | []             | 0                 | NumberIntVal(-2)                 |
      | `(! true)`               | {}                 | []             | 0                 | False                            |
      | `true`                   | {}                 | []             | 0                 | True                             |
      | `null`                   | {}                 | []             | 0                 | NullVal(DynamicPseudoType)       |
      | `"hello"`                | {}                 | []             | 0                 | StringVal("hello")               |
      | `"hello \\`backtick\\` world"` | {}            | []             | 0                 | StringVal("hello `backtick` world") |
      | `"unclosed`              | {}                 | []             | 1                 | StringVal("unclosed")            | # Unterminated template string
      # Templates
      | `"hello ${"world"}"`     | {}                 | []             | 0                 | StringVal("hello world")         |
      | `"silly ${"${true}"}"`   | {}                 | []             | 0                 | StringVal("silly true")          |
      | `"hello $${escaped}"`    | {}                 | []             | 0                 | StringVal("hello ${escaped}")    |
      # Function Calls
      | `upper("foo")`           | {}                 | ["upper"]      | 0                 | StringVal("FOO")                 |
      | `upper(["foo"]...)`      | {}                 | ["upper"]      | 0                 | StringVal("FOO")                 |
      | `upper("foo", "bar")`    | {}                 | ["upper"]      | 1                 | DynamicVal                       | # too many args
      | `foo::upper("foo")`      | {}                 | ["foo::upper"] | 0                 | StringVal("FOO")                 |
      | `misbehave()`            | {}                 | ["misbehave_out_of_range_arg_err"] | 1 | DynamicVal                   | # specific misbehaving func
      # Collections
      | `[]`                     | {}                 | []             | 0                 | EmptyTupleVal                    |
      | `[1,]`                   | {}                 | []             | 0                 | TupleVal([NumberIntVal(1)])      |
      | `{"hello": "world"}`     | {}                 | []             | 0                 | ObjectVal({hello:StringVal("world")}) |
      | `{hello = "world"}`      | {}                 | []             | 0                 | ObjectVal({hello:StringVal("world")}) |
      | `{(var.greeting)="world"}`| `{"var":{"greeting":"hello"}}` | [] | 0               | ObjectVal({hello:StringVal("world")}) |
      # For Expressions
      | `[for k,v in {a:"b"}:k]` | {}                 | []             | 0                 | TupleVal([StringVal("a")])       |
      | `{for v in ["w"]:v=>v}`  | {}                 | []             | 0                 | ObjectVal({w:StringVal("w")})    |
      | `[for v in "s":v]`       | {}                 | []             | 1                 | DynamicVal                       | # can't iterate string
      | `[for v in unk:v]`       | `{"unk":"?[string]"}`| []           | 0                 | DynamicVal                       | # unk is UnknownVal(List(String))
      # Splat Expressions
      | `[{n:"S"},{n:"E"}].*.n`  | {}                 | []             | 0                 | TupleVal([StringVal("S"),StringVal("E")]) |
      | `null[*]`                | {}                 | []             | 0                 | EmptyTupleVal                    |
      | `unkstr[*].name`         | `{"unkstr":"?"}`   | []             | 1                 | DynamicVal                       | # unkstr is UnknownVal(String), error: string has no attr "name"
      | `["hello"][0]`           | {}                 | []             | 0                 | StringVal("hello")               |
      # Variables & Traversals
      | `foo`                    | `{"foo":"hello"}`  | []             | 0                 | StringVal("hello")               |
      | `bar`                    | {}                 | []             | 1                 | DynamicVal                       | # var not allowed
      | `foo.baz`                | `{"foo":{"baz":"hello"}}` | []     | 0                 | StringVal("hello")               |
      # Logical Ops Short-circuiting
      | `nullObj != null && nullObj.is_thingy` | `{"nullObj":null}` | [] | 0             | False                            | # nullObj is NullVal(Object({is_thingy:Bool}))
      | `unknown < 4 && list[zero]` | `{"unknown":"?","zero":0,"list":[]}` | [] | 0       | UnknownVal(Bool).NotNull()       | # unknown is UnknownVal(Number), list is EmptyTupleVal
      | `true ? var : null`        | `{"var":{"a":"A"}}`| []             | 0                 | ObjectVal({a:StringVal("A")})    |
      | `unknown ? 1 : 0`        | `{"unknown":"?bool"}`| []           | 0                 | UnknownVal(Number).NotNull().Range(0,1) | # unknown is UnknownVal(Bool)
      # Bool Expressions (selected examples from TestAllBoolExpressions)
      | `true && true`           | {}                 | []             | 0                 | True                             |
      | `false || unknown`       | `{"unknown":"?dyn"}`| []           | 0                 | UnknownVal(Bool).NotNull()       | # unknown is UnknownVal(DynamicPseudoType)
      | `true || true && false`  | {}                 | []             | 0                 | True                             |
      | `(false && true) || true`| {}                 | []             | 0                 | True                             |

  Scenario Outline: HCL expression error messages
    Given an HCL expression string: "<expression_string>"
    And an evaluation context:
      | type      | details                                       |
      | variables | <variables_map_json>                          |
    When the expression string is parsed
    And the parsed expression is evaluated with the context
    Then at least one error diagnostic should be reported
    And one of the error diagnostics should have Summary "<expected_summary>" and Detail "<expected_detail>"

    Examples:
      | expression_string        | variables_map_json | expected_summary                     | expected_detail                                                                                                                              |
      | `true ? 1 : true`        | {}                 | Inconsistent conditional result types| The true and false result expressions must have consistent types. The 'true' value is number, but the 'false' value is bool.               |
      | `true ? [1] : [1, true]` | {}                 | Inconsistent conditional result types| The true and false result expressions must have consistent types. The 'true' tuple has length 1, but the 'false' tuple has length 2.         |
      | `true ? {a=1} : {a=true}`| {}                 | Inconsistent conditional result types| The true and false result expressions must have consistent types. Type mismatch for object attribute "a": The 'true' value is number, but the 'false' value is bool. |
      | `notobj != null && notobj.foo` | `{"notobj":true}`| Unsupported attribute                | Can't access attributes on a primitive-typed value (bool).                                                                         |
      | `value != null && valeu` | `{"value":true}`   | Unknown variable                     | There is no variable named "valeu". Did you mean "value"?                                                                              |
      | `unknown && "value"`     | `{"unknown":"?bool"}`| Invalid operand                      | Unsuitable value for right operand: a bool is required.                                                                              | # unknown is UnknownVal(Bool)

  Scenario Outline: FunctionCallExpr Value method
    Given a FunctionCallExpr for function "<func_name>" with arguments <arg_expressions_json_list>
    And an evaluation context with functions: <functions_list>
    When the FunctionCallExpr's `Value` method is called with the context
    Then the number of diagnostics should be <diagnostics_count>
    And the resulting cty.Value should be <expected_cty_value_string>

    Examples:
      | func_name  | arg_expressions_json_list | functions_list         | diagnostics_count | expected_cty_value_string         |
      | "length"   | `["hello"]`               | ["length"]             | 0                 | NumberIntVal(5)                   |
      | "length"   | `[true]`                  | ["length"]             | 0                 | NumberIntVal(4)                   | # "true" -> 4
      | "length"   | `["?string"]`             | ["length"]             | 0                 | UnknownVal(Number).NotNull().Min(0) | # Arg is UnknownVal(String)
      | "length"   | `["?bool"]`               | ["length"]             | 0                 | UnknownVal(Number).NotNull().Min(0) | # Arg is UnknownVal(Bool)
      | "length"   | `["?dyn"]`                | ["length"]             | 0                 | UnknownVal(Number).NotNull().Min(0) | # Arg is DynamicVal
      | "length"   | `[["hello"]]`             | ["length"]             | 1                 | DynamicVal                        | # Invalid arg type (list)
      | "jsondecode"| `["\"hello\""]`           | ["jsondecode"]         | 0                 | StringVal("hello")                |
      | "jsondecode"| `["?string"]`             | ["jsondecode"]         | 0                 | DynamicVal                        | # Arg is UnknownVal(String)
      | "jsondecode"| `["invalid-json"]`        | ["jsondecode"]         | 1                 | DynamicVal                        | # JSON parse error
      | "lenth"    | `[]`                      | ["length","jsondecode"]| 1                 | DynamicVal                        | # Unknown function

  Scenario: ExpressionAsTraversal method
    Given an HCL expression string "a.b[0][\"c\"]" is parsed
    When `hcl.AbsTraversalForExpr` is called on the parsed expression
    Then no diagnostics should be reported
    And the resulting traversal should have 4 steps:
      | Step | Type            | Name | Key (for Index) |
      | 0    | TraverseRoot    | a    |                 |
      | 1    | TraverseAttr    | b    |                 |
      | 2    | TraverseIndex   |      | NumberIntVal(0) |
      | 3    | TraverseIndex   |      | StringVal("c")  |

  Scenario: StaticExpressionList method
    Given an HCL expression string "[0, a, true]" is parsed
    When `hcl.ExprList` is called on the parsed expression
    Then no diagnostics should be reported
    And the resulting list of expressions should have 3 elements
    And the first element should be a LiteralValueExpr with value NumberIntVal(0)

  Scenario Outline: Parsing incomplete function call expressions and checking ranges
    Given an HCL expression string: "<expression_string>"
    When the expression string is parsed
    Then the expression's root `Range()` should be <expected_range_string>

    Examples:
      | expression_string       | expected_range_string    |
      | `object({ foo = })`     | "test.hcl:1,1-18"        |
      | `object({\n  foo = \n})` | "test.hcl:1,1-3,3"       |
      | `object({ foo = }`      | "test.hcl:0,0-0"         | # Range becomes zero due to EOF
      | `object({\n  foo = \n}` | "test.hcl:0,0-0"         | # Range becomes zero due to EOF

    # Notes for tables:
    # - Variables map: JSON string like `{"varName":"value"}` or `{"varName":"?type"}` for unknown. `?dyn` for DynamicVal.
    # - Functions list: e.g., ["upper", "jsondecode"]. "misbehave_out_of_range_arg_err" for the specific erroring function.
    # - cty.Value string: e.g., "NumberIntVal(1)", "True", "StringVal(\"hello\")", "UnknownVal(Number).NotNull()".
    # - Range string for `TestParseExpression_incompleteFunctionCall` is simplified to "filename:startLine,startCol-endCol". Actual ranges include byte offsets.
    # - The `TestAllBoolExpressions` is represented by a few selected examples for boolean logic. The full truth table is extensive.
    # - `expected_cty_value_string` for unknown values may include refinements like `.NotNull()` or `.Range(0,1)`.
    # - `filename` for ParseExpression tests is empty string. For `TestParseExpression_incompleteFunctionCall` it's "test.hcl".
