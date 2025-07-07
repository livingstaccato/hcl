# Covers tests in ./json/structure_test.go
# Specifically, TestBodyPartialContent, TestBodyContent, TestJustAttributes,
# TestExpressionVariables, TestExpressionAsTraversal, TestStaticExpressionList,
# TestExpression_Value, and TestExpressionValue_Diags.

Feature: JSON HCL Body Structure and Expression Handling
  This feature tests how a parsed JSON HCL `Body` object provides its content
  (attributes and blocks) according to a schema, and how expressions derived
  from this structure behave (variable extraction, evaluation, traversal).

  Background:
    Given a JSON HCL input string is parsed into a File object with filename "test.json".
    And a Body object is obtained from this File.

  Scenario Outline: Body PartialContent method for attributes and blocks
    Given a JSON input: "<input_json>"
    And a BodySchema:
      | type              | schema_details                                   |
      | attributes        | <attrs_schema>                                   |
      | blocks            | <blocks_schema>                                  |
    When the Body's `PartialContent` method is called with the schema
    Then the number of diagnostics should be <expected_diag_count>
    And the returned BodyContent should have:
      | type              | content_details                                  |
      | attributes        | <expected_attrs_content>                         |
      | blocks            | <expected_blocks_content>                        |
      | missing_item_range| <expected_missing_item_range>                    |
    # 'remain' part of PartialContent is not explicitly checked here, assumed covered by what's requested.

    Examples:
      | input_json        | attrs_schema                               | blocks_schema                             | expected_diag_count | expected_attrs_content            | expected_blocks_content | expected_missing_item_range |
      | `{}`              | (empty)                                    | (empty)                                   | 0                   | {}                                | (empty)                 | L1C2-L1C3 (B1-B2)           |
      | `[]`              | (empty)                                    | (empty)                                   | 0                   | {}                                | (empty)                 | L1C1-L1C2 (B0-B1)           | # Root array means no top-level attrs/blocks
      | `[{}]`            | (empty)                                    | (empty)                                   | 0                   | {}                                | (empty)                 | L1C1-L1C2 (B0-B1)           | # Root array of objects
      | `[[]]`            | (empty)                                    | (empty)                                   | 1                   | {}                                | (empty)                 | L1C1-L1C2 (B0-B1)           | # Root array elements must be objects
      | `{"//":"comment"}`| (empty)                                    | (empty)                                   | 0                   | {}                                | (empty)                 | L1C18-L1C19 (B17-B18)       | # Comments ignored
      | `{"name":"val"}`  | [{name:"name"}]                            | (empty)                                   | 0                   | {name: Attr("name",Expr(Str("val")))} | (empty)               | L1C15-L1C16 (B14-B15)       |
      | `[{"name":"val"}]`| [{name:"name"}]                            | (empty)                                   | 0                   | {name: Attr("name",Expr(Str("val")))} | (empty)               | L1C1-L1C2 (B0-B1)           | # Attribute from first object in root array
      | `{"name":"val"}`  | [{name:"name",req:true},{name:"age",req:true}] | (empty)                                 | 1                   | {name: Attr("name",Expr(Str("val")))} | (empty)               | L1C15-L1C16 (B14-B15)       | # Missing required 'age'
      | `{"res":null}`    | (empty)                                    | [{type:"res"}]                            | 0                   | {}                                | (empty)                 | L1C13-L1C14 (B12-B13)       | # Null block value means no blocks
      | `{"res":{}}`      | (empty)                                    | [{type:"res"}]                            | 0                   | {}                                | [Block("res")]          | L1C10-L1C11 (B9-B10)        |
      | `{"res":[{},{}]}` | (empty)                                    | [{type:"res"}]                            | 0                   | {}                                | [Block("res"),Block("res")] | L1C15-L1C16 (B14-B15)     |
      | `{"res":{"L1":{"L2":{}}}}` | (empty)                             | [{type:"res",labels:["type","name"]}]     | 0                   | {}                                | [Block("res","L1","L2")]| L1C25-L1C26 (B24-B25)     |
      | `{"res":{"L1":[{"L2":{}},{"L2":{}}]}}` | (empty)                   | [{type:"res",labels:["type","name"]}]     | 0                   | {}                                | [Block("res","L1","L2"),Block("res","L1","L2")] | L1C39-L1C40 (B38-B39) |
      | `{"name":"val"}`  | (empty)                                    | [{type:"name"}]                           | 1                   | {}                                | (empty)                 | L1C15-L1C16 (B14-B15)       | # 'name' requested as block, but is attr
      | `[{"n":"v"},{"n":"v"}]` | [{name:"n"}]                           | (empty)                                   | 1                   | {n: Attr("n",Expr(Str("v")))}     | (empty)                 | L1C1-L1C2 (B0-B1)           | # Attr 'n' defined twice via array merge

  Scenario Outline: Body Content method (checking extraneous attributes)
    Given a JSON input: "<input_json>"
    And a BodySchema:
      | type              | schema_details                                   |
      | attributes        | <attrs_schema>                                   |
    When the Body's `Content` method is called with the schema
    Then the number of diagnostics should be <expected_diag_count>

    Examples:
      | input_json        | attrs_schema      | expected_diag_count |
      | `{"unknown":true}`| (empty)           | 1                   | # Extraneous attribute
      | `{"//":"comment"}`| (empty)           | 0                   | # Comment is not extraneous
      | `{"unknow":true}` | [{name:"unknown"}]| 1                   | # Misspelled attribute is extraneous
      | `{"u1":true,"u2":true}`| [{name:"unknown"}]| 2               | # Multiple extraneous

  Scenario Outline: Body JustAttributes method
    Given a JSON input: "<input_json>"
    When the Body's `JustAttributes` method is called
    Then the number of diagnostics should be <expected_diag_count>
    And the returned hcl.Attributes map should be <expected_attrs_map>

    Examples:
      | input_json        | expected_diag_count | expected_attrs_map        |
      | `{}`              | 0                   | {}                        |
      | `{"foo":true}`    | 0                   | {foo: Attr("foo",Expr(Bool(true)))} |
      | `{"//":"comment"}`| 0                   | {}                        |
      | `{"foo":true, "foo":true}` | 1          | {foo: Attr("foo",Expr(Bool(true)))} | # Duplicate attribute error

  Scenario Outline: Expression Variables method
    Given a JSON input: `{"a":<value_json>}`
    When attributes are extracted using `JustAttributes`
    And the `Variables` method is called on the expression for attribute "a"
    Then the returned list of hcl.Traversal should be <expected_traversals>

    Examples:
      | value_json        | expected_traversals                               |
      | `true`            | (empty)                                           |
      | `"${foo}"`        | [Traversal(TraverseRoot("foo" L1C9-L1C12))]       |
      | `["${foo}"]`      | [Traversal(TraverseRoot("foo" L1C10-L1C13))]      |
      | `{"b":"${foo}"}`  | [Traversal(TraverseRoot("foo" L1C14-L1C17))]      |
      | `{"${foo}":"b"}`  | [Traversal(TraverseRoot("foo" L1C10-L1C13))]      | # Variable in object key

  Scenario: Expression AsTraversal method
    Given an expression from a JSON string value "foo.bar[0]"
    When `AsTraversal` is called on the expression
    Then the resulting traversal should have 3 steps: TraverseRoot("foo"), TraverseAttr("bar"), TraverseIndex(0)

  Scenario: Expression ExprList method for static array
    Given an expression from a JSON array `["hello"]`
    When `ExprList` is called on the expression
    Then the resulting list of expressions should contain 1 expression
    And that expression's underlying node should be the string node "hello"

  Scenario Outline: Expression Value method for various types
    Given a JSON input: "<input_json_object_with_key_v>"
    And an hcl.EvalContext with variable "VAR1" as string "case"
    When attributes are extracted using `JustAttributes`
    And the `Value` method is called on the expression for attribute "v" with the context
    Then the resulting cty.Value should be <expected_cty_value>
    And if an error is expected, the diagnostics should contain "<expected_error_substring>"
    And if no error is expected, no diagnostics should be reported

    Examples:
      | input_json_object_with_key_v | expected_cty_value                                  | expected_error_substring |
      | `{"v": "string_val"}`        | StringVal("string_val")                             |                          |
      | `{"v": 5}`                   | NumberIntVal(5)                                     |                          |
      | `{"v": true}`                | True                                                |                          |
      | `{"v": false}`               | False                                               |                          |
      | `{"v": ["a"]}`               | TupleVal([StringVal("a")])                          |                          |
      | `{"v": {"key": "value"}}`    | ObjectVal({key:StringVal("value")})                 |                          |
      | `{"v": null}`                | NullVal(DynamicPseudoType)                          |                          |
      # Cases with interpolations and potential errors
      | `{"v": "happy ${VAR1}"}`     | StringVal("happy case")                             |                          |
      | `{"v": "happy ${UNKNOWN}"}`  | UnknownVal(String).RefineNotNull()                  | "Unknown variable"       |
      | `{"v": {"key": "happy ${VAR1}"}}` | ObjectVal({key:StringVal("happy case")})        |                          |
      | `{"v": {"key": "happy ${UNKNOWN}"}}` | ObjectVal({key:UnknownVal(String).RefineNotNull()}) | "Unknown variable"       |
      | `{"v": {"happy ${VAR1}": "val"}}` | ObjectVal({"happy case":StringVal("val")})      |                          |
      | `{"v": {"happy ${UNKNOWN}": "val"}}` | DynamicVal                                          | "Unknown variable"       | # Key interpolation failure makes whole object dynamic
      | `{"v": ["happy ${VAR1}"]}`   | TupleVal([StringVal("happy case")])                 |                          |
      | `{"v": ["happy ${UNKNOWN}"]}`| TupleVal([UnknownVal(String).RefineNotNull()])      | "Unknown variable"       |

    # Notes for tables:
    # - (empty) for schema/content means an empty list/map.
    # - Attr("name",Expr(Node(val))) is a simplified representation of hcl.Attribute.
    # - Block("type", "L1", "L2") represents an hcl.Block.
    # - Ranges like L1C2-L1C3 (B1-B2) are hcl.Range.
    # - Traversal(TraverseRoot("name" Range)) is a simplified hcl.Traversal.
    # - cty.Value representations like StringVal("v"), NumberIntVal(5), True, False, etc.
    # - NullVal(DynamicPseudoType) is cty.NullVal(cty.DynamicPseudoType).
    # - UnknownVal(String).RefineNotNull() indicates an unknown value that is guaranteed not to be null.
    # - DynamicVal is cty.DynamicVal.
