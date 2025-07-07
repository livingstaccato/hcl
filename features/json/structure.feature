# Covers hcl.Body and hcl.Expression implementations for JSON syntax in ./json/structure.go
# Based on test cases in ./json/structure_test.go

Feature: JSON HCL Body Structure and Expression Handling
  This feature tests how a parsed JSON HCL structure (represented by `json.body`
  and `json.expression`) interacts with the `hcl.Body` and `hcl.Expression`
  interfaces. It covers content retrieval based on a schema, attribute/block
  handling, expression evaluation (including templates in strings), and static
  analysis of expressions.

  Scenario Outline: JSON Body PartialContent method for attributes and blocks
    Given a JSON input string: "<input_json_string>" parsed into a JSON body for filename "test.json"
    And an `hcl.BodySchema` defined with:
      Attributes: <attrs_schema_json_list>  # e.g., [{"Name":"name","Required":false}]
      Blocks: <blocks_schema_json_list>    # e.g., [{"Type":"res","LabelNames":["type","name"]}]
    When the JSON body's `PartialContent` method is called with the schema
    Then the number of diagnostics should be <expected_diag_count>
    And the returned `hcl.BodyContent.Attributes` should match: <expected_attrs_map_repr>
    And the returned `hcl.BodyContent.Blocks` should match: <expected_blocks_list_repr>
    And the `hcl.BodyContent.MissingItemRange` should be at <expected_missing_item_range_desc>

    Examples:
      | input_json_string        | attrs_schema_json_list         | blocks_schema_json_list       | expected_diag_count | expected_attrs_map_repr        | expected_blocks_list_repr      | expected_missing_item_range_desc |
      | `{}`                     | `[]`                           | `[]`                          | 0                   | `{}`                           | `[]`                           | "end of root object (L1C2-L1C3)" |
      | `[]`                     | `[]`                           | `[]`                          | 0                   | `{}`                           | `[]`                           | "start of root array (L1C1-L1C2)"|
      | `[{}]`                   | `[]`                           | `[]`                          | 0                   | `{}`                           | `[]`                           | "start of root array (L1C1-L1C2)"|
      | `[[]]`                   | `[]`                           | `[]`                          | 1                   | `{}`                           | `[]`                           | "start of root array (L1C1-L1C2)"| # Err: root array elements must be objects
      | `{"//":"comment"}`       | `[]`                           | `[]`                          | 0                   | `{}`                           | `[]`                           | "end of comment value (L1C40-L1C41)" |
      | `{"name":"E"}`           | `[{"Name":"name"}]`            | `[]`                          | 0                   | `{"name":Attr("name",StrVal("E"))}`| `[]`                         | "end of object (L1C21-L1C22)"   |
      | `[{"name":"E"}]`         | `[{"Name":"name"}]`            | `[]`                          | 0                   | `{"name":Attr("name",StrVal("E"))}`| `[]`                         | "start of root array (L1C1-L1C2)"| # Attr from first obj in array
      | `{"name":"E"}`           | `[{"Name":"name","Required":true},{"Name":"age","Required":true}]` | `[]`            | 1                   | `{"name":Attr("name",StrVal("E"))}`| `[]`                         | "end of object (L1C21-L1C22)"   | # Missing "age"
      | `{"res":null}`           | `[]`                           | `[{"Type":"res"}]`            | 0                   | `{}`                           | `[]`                           | "end of object (L1C18-L1C19)"   | # Null block value -> no blocks
      | `{"res":{}}`             | `[]`                           | `[{"Type":"res"}]`            | 0                   | `{}`                           | `[Block("res")]`               | "end of object (L1C15-L1C16)"   |
      | `{"res":[{},{}]}`        | `[]`                           | `[{"Type":"res"}]`            | 0                   | `{}`                           | `[Block("res"), Block("res")]` | "end of object (L1C20-L1C21)"   |
      | `{"res":{"l1":{"l2":{}}}}`| `[]`                           | `[{"Type":"res","LabelNames":["t","n"]}]` | 0        | `{}`                           | `[Block("res","l1","l2")]`     | "end of object (L1C40-L1C41)"   |
      | `[{"n":"E"},{"n":"E"}]`  | `[{"Name":"n"}]`               | `[]`                          | 1                   | `{"n":Attr("n",StrVal("E"))}`  | `[]`                           | "start of root array (L1C1-L1C2)"| # Duplicate attr "n" via array merge

  Scenario Outline: JSON Body Content method (checking extraneous properties)
    Given a JSON input string: "<input_json_string>" parsed into a JSON body
    And an `hcl.BodySchema` defined with Attributes: <attrs_schema_json_list> and Blocks: <blocks_schema_json_list>
    When the JSON body's `Content` method is called with the schema
    Then the number of diagnostics should be <expected_diag_count>
    And if diagnostics are expected, the first summary should contain "<expected_error_summary_contains>"

    Examples:
      | input_json_string | attrs_schema_json_list | blocks_schema_json_list | expected_diag_count | expected_error_summary_contains |
      | `{"unknown":true}`  | `[]`                   | `[]`                    | 1                   | "Extraneous JSON object property" |
      | `{"//":"comment"}`| `[]`                   | `[]`                    | 0                   |                                   |
      | `{"unknow":true}` | `[{"Name":"unknown"}]` | `[]`                    | 1                   | "Extraneous JSON object property" | # Did you mean "unknown"?

  Scenario Outline: JSON Body JustAttributes method
    Given a JSON input string: "<input_json_string>" parsed into a JSON body
    When the JSON body's `JustAttributes` method is called
    Then the number of diagnostics should be <expected_diag_count>
    And the returned `hcl.Attributes` map should match: <expected_attrs_map_repr>
    And if diagnostics are expected, the first summary should contain "<expected_error_summary_contains>"

    Examples:
      | input_json_string             | expected_diag_count | expected_attrs_map_repr        | expected_error_summary_contains |
      | `{}`                          | 0                   | `{}`                           |                                 |
      | `{"foo":true}`                | 0                   | `{"foo":Attr("foo",BoolVal(true))}`|                                 |
      | `{"//":"comment"}`            | 0                   | `{}`                           |                                 |
      | `{"foo":true, "foo":false}`   | 1                   | `{"foo":Attr("foo",BoolVal(true))}`| "Duplicate attribute definition"| # First one wins

  Scenario Outline: JSON Expression evaluation (Value method)
    Given a JSON input string: `{"v": <value_json_string>}` parsed into a JSON body
    And an attribute "v_attr" is obtained from the body for key "v"
    And an `hcl.EvalContext` "Ctx" with variable "VAR1" = StringVal("case") and "UNKNOWN" which is undefined
    When `v_attr.Expr.Value(Ctx)` is called
    Then the resulting cty.Value should be <expected_cty_value_repr>
    And the number of evaluation diagnostics should be <expected_diag_count>
    And if diagnostics are expected, the first summary should contain "<expected_error_summary_contains>"

    Examples:
      | value_json_string       | expected_cty_value_repr                  | expected_diag_count | expected_error_summary_contains |
      | `"string_val"`          | `StringVal("string_val")`                | 0                   |                                 |
      | `5`                     | `NumberIntVal(5)`                        | 0                   |                                 |
      | `true`                  | `True`                                   | 0                   |                                 |
      | `["a"]`                 | `TupleVal([StringVal("a")])`             | 0                   |                                 |
      | `{"key":"value"}`       | `ObjectVal({"key":StringVal("value")})`  | 0                   |                                 |
      | `null`                  | `NullVal(DynamicPseudoType)`             | 0                   |                                 |
      | `"happy ${VAR1}"`       | `StringVal("happy case")`                | 0                   |                                 |
      | `"happy ${UNKNOWN}"`    | `UnknownVal(String).NotNull()`           | 1                   | "Unknown variable"              |
      | `{"key":"happy ${VAR1}"}`| `ObjectVal({"key":StringVal("happy case")})`| 0                 |                                 |
      | `{"happy ${UNKNOWN}":"val"}`| `DynamicVal`                           | 1                   | "Unknown variable"              | # Interpolated key unknown

  Scenario Outline: JSON Expression static analysis (Variables, AsTraversal, ExprList, ExprMap)
    Given a JSON input string: `{"attr_key": <value_json_string>}` parsed into a JSON body
    And attribute "expr_attr" is obtained from the body for key "attr_key"
    When `expr_attr.Expr.<Method>()` is called
    Then the result should be <expected_result_repr>
    And the number of diagnostics should be <expected_diag_count>

    Examples:
      | value_json_string   | Method        | expected_result_repr                                   | expected_diag_count |
      | `true`              | Variables     | `[]` (empty traversals)                                | 0                   |
      | `"${foo}"`          | Variables     | `[Traversal(TraverseRoot("foo"))]`                     | 0                   |
      | `["${foo}"]`        | Variables     | `[Traversal(TraverseRoot("foo"))]`                     | 0                   |
      | `{"b":"${foo}"}`    | Variables     | `[Traversal(TraverseRoot("foo"))]`                     | 0                   |
      | `{"${foo}":"b"}`    | Variables     | `[Traversal(TraverseRoot("foo"))]`                     | 0                   | # Var in key
      | `"foo.bar[0]"`      | AsTraversal   | `Traversal(Root("foo"),Attr("bar"),Index(0))`          | 0                   |
      | `"not_a_traversal"` | AsTraversal   | `(nil)`                                                | 1                   | # (Static diagnostic from hclsyntax.ParseTraversalAbs)
      | `["hello"]`         | ExprList      | `[Expression(src:StringVal("hello"))]`                 | 0                   |
      | `{}`                | ExprList      | `(nil)`                                                | 1                   | # Not a list
      | `{"k":"v"}`         | ExprMap       | `[{Key:Expr(StrVal("k")), Value:Expr(StrVal("v"))}]`   | 0                   |
      | `[]`                | ExprMap       | `(nil)`                                                | 1                   | # Not a map

    # Notes for table values:
    # - JSON representations are strings. `attrs_schema_json_list` and `blocks_schema_json_list` are stringified JSON for Gherkin.
    # - `expected_attrs_map_repr` and `expected_blocks_list_repr` describe the expected hcl.Attributes and hcl.Blocks.
    #   - `Attr("name",TypeVal(val))` e.g. `Attr("name",StrVal("E"))` means hcl.Attribute{Name:"name", Expr:json.expression{src:&json.stringVal{Value:"E", ...}}}.
    #   - `Block("type", Labels:[...])`
    # - `expected_missing_item_range_desc` is a human-readable description of the range.
    # - `cty_value_repr` is a cty string representation. `StrVal`, `Num`, `BoolVal`, `ObjVal`, `TupleVal`, `NullVal`, `UnknownVal`, `DynamicVal`.
    # - `Traversal(...)` is a simplified representation of hcl.Traversal.
    # - `Expression(src:...)` indicates a json.expression with the specified underlying json.node.
    # - `(nil)` means the Go slice/map is nil.
