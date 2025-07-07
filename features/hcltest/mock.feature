# Covers tests in ./hcltest/mock_test.go
# Specifically, TestMockBodyPartialContent, TestExprList, and TestExprMap

Feature: HCL Test Mocking Utilities
  This feature tests the utility functions in the `hcltest` package,
  which are used for creating mock HCL bodies and expressions for testing purposes.
  It covers `MockBody`'s `PartialContent` method, and the HCL helper
  functions `ExprList` and `ExprMap` when used with mock expressions.

  Scenario Outline: MockBody PartialContent method
    Given a MockBody created with initial content:
      | type       | attributes                               | blocks                                     |
      | attributes | <initial_attrs>                          |                                            |
      | blocks     |                                          | <initial_blocks>                           |
    And a BodySchema:
      | type       | attributes_schema | blocks_schema                              |
      | attributes | <attrs_schema>    |                                            |
      | blocks     |                   | <blocks_schema>                            |
    When PartialContent is called on the MockBody with the schema
    Then the number of diagnostics should be <expected_diag_count>
    And the returned BodyContent should have:
      | type       | attributes          | blocks              |
      | attributes | <expected_attrs>    |                     |
      | blocks     |                     | <expected_blocks>   |
    And the remaining BodyContent in the MockBody should have:
      | type       | attributes          | blocks              |
      | attributes | <remaining_attrs>   |                     |
      | blocks     |                     | <remaining_blocks>  |

    Examples:
      | initial_attrs                      | initial_blocks              | attrs_schema           | blocks_schema                      | expected_diag_count | expected_attrs                     | expected_blocks           | remaining_attrs                    | remaining_blocks          |
      | (empty)                            | (empty)                     | (empty)                | (empty)                            | 0                   | (empty)                            | (empty)                   | (empty)                            | (empty)                   | # empty
      | {name: "Ermintrude"}               | (empty)                     | [{name: "name"}]       | (empty)                            | 0                   | {name: "Ermintrude"}               | (empty)                   | (empty)                            | (empty)                   | # attribute requested
      | {name: "Ermintrude"}               | (empty)                     | (empty)                | (empty)                            | 0                   | (empty)                            | (empty)                   | {name: "Ermintrude"}               | (empty)                   | # attribute remains
      | (empty)                            | (empty)                     | [{name: "name", required: true}] | (empty)                | 1                   | (empty)                            | (empty)                   | (empty)                            | (empty)                   | # attribute missing
      | (empty)                            | [{type: "baz"}]             | (empty)                | [{type: "baz"}]                    | 0                   | (empty)                            | [{type: "baz"}]           | (empty)                            | (empty)                   | # block requested, no labels
      | (empty)                            | [{type: "baz"}]             | (empty)                | [{type: "baz", labels: ["foo"]}]   | 1                   | (empty)                            | [{type: "baz"}]           | (empty)                            | (empty)                   | # block requested, wrong labels
      | (empty)                            | [{type: "baz"}]             | (empty)                | (empty)                            | 0                   | (empty)                            | (empty)                   | (empty)                            | [{type: "baz"}]           | # block remains
      | {name:"Ermintrude", age:32}        | [{type:"baz"},{type:"bar",labels:["foo1"]},{type:"bar",labels:["foo2"]}] | [{name:"name"}] | [{type:"bar",labels:["name"]}] | 0                   | {name:"Ermintrude"}        | [{type:"bar",labels:["foo1"]},{type:"bar",labels:["foo2"]}] | {age:32}                   | [{type:"baz"}]            | # various

  Scenario Outline: hcl.ExprList with Mock Expressions
    Given a MockExprLiteral created from the cty.Value: <input_cty_value>
    When hcl.ExprList is called with this mock expression
    Then the resulting list of hcl.Expression should be <expected_expressions>
    And if an error is expected, the diagnostics should contain "<expected_error_message>"
    And if no error is expected, no error diagnostics should be reported

    Examples:
      | input_cty_value             | expected_expressions                           | expected_error_message      |
      | ListVal(["foo", "bar"])     | [MockExprLiteral("foo"), MockExprLiteral("bar")] |                             | # as list
      | TupleVal(["foo", "bar"])    | [MockExprLiteral("foo"), MockExprLiteral("bar")] |                             | # as tuple
      | ObjectVal({a:"foo",b:"bar"}) | (nil)                                          | list expression is required | # not list

  Scenario Outline: hcl.ExprMap with Mock Expressions
    Given a MockExprLiteral created from the cty.Value: <input_cty_value>
    When hcl.ExprMap is called with this mock expression
    Then the resulting list of hcl.KeyValuePair should be <expected_key_value_pairs> (order may vary for objects)
    And if an error is expected, the diagnostics should contain "<expected_error_message>"
    And if no error is expected, no error diagnostics should be reported

    Examples:
      | input_cty_value                      | expected_key_value_pairs                                     | expected_error_message    |
      | ObjectVal({name:"test", count:2})    | [{key:Lit("count"),val:Lit(2)},{key:Lit("name"),val:Lit("test")}] |                           | # as object
      | MapVal({name:"test", version:"2.0.0"}) | [{key:Lit("name"),val:Lit("test")},{key:Lit("version"),val:Lit("2.0.0")}] |                           | # as map
      | ListVal(["foo", "bar"])              | (nil)                                                        | map expression is required  | # not map

    # Notes for tables:
    # - (empty) for attributes/blocks means an empty map/slice.
    # - Attributes are represented as {key: value_expr_string}, e.g., {name: "Ermintrude"}.
    # - Blocks are [{type:"type", labels:["l1","l2"]}].
    # - Attribute schemas are [{name:"name", required:true/false}].
    # - Block schemas are [{type:"type", labels:["labelName"]}].
    # - MockExprLiteral("value") or Lit("value") implies MockExprLiteral(cty.StringVal("value")) or cty.NumberIntVal if numeric.
    # - KeyValuePair has Key and Value as hcl.Expression.
    # - Order of KeyValuePairs from ObjectVal is not guaranteed and should be checked ignoring order.```
      | input_cty_value                      | expected_key_value_pairs                                     | expected_error_message    |
      | ObjectVal({name:"test", count:2})    | [{key:Lit("count"),val:Lit(2)},{key:Lit("name"),val:Lit("test")}] |                           | # as object
      | MapVal({name:"test", version:"2.0.0"}) | [{key:Lit("name"),val:Lit("test")},{key:Lit("version"),val:Lit("2.0.0")}] |                           | # as map
      | ListVal(["foo", "bar"])              | (nil)                                                        | map expression is required  | # not map
```

Notes for tables:
- (empty) for attributes/blocks means an empty map/slice.
- Attributes are represented as `{key: value_expr_string}`, e.g., `{name: "Ermintrude"}`. Internally, these are `MockExprLiteral(cty.StringVal("Ermintrude"))`.
- Blocks are `[{type:"type", labels:["l1","l2"]}]`.
- Attribute schemas are `[{name:"name", required:true/false}]`.
- Block schemas are `[{type:"type", labels:["labelName"]}]`.
- `MockExprLiteral("value")` or `Lit("value")` implies `MockExprLiteral(cty.StringVal("value"))` or `cty.NumberIntVal` if numeric.
- KeyValuePair has Key and Value as `hcl.Expression`.
- Order of KeyValuePairs from `ObjectVal` is not guaranteed and should be checked ignoring order.
- `ListVal`, `TupleVal`, `ObjectVal`, `MapVal` are cty value constructors.
