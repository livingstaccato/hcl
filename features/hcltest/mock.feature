# Covers utilities in ./hcltest/mock.go
# Based on test cases in ./hcltest/mock_test.go and analysis of mock.go

Feature: HCL Test Mocking Utilities
  This feature tests the utility functions and mock types in the `hcltest` package,
  which are used for creating mock HCL bodies and expressions for testing HCL API interactions.

  Scenario Outline: MockBody PartialContent method
    Given a MockBody created with initial content: <initial_content_json>
      # initial_content_json is a JSON-like representation of hcl.BodyContent
      # e.g., {"Attributes":{"name":"ExprLit(Str(E))"}, "Blocks":[{"Type":"baz"}]}
    And a BodySchema defined with:
      Attributes: <attrs_schema_json> # e.g., [{"Name":"name","Required":false}]
      Blocks: <blocks_schema_json>   # e.g., [{"Type":"bar","LabelNames":["name"]}]
    When `PartialContent` is called on the MockBody with the schema
    Then the number of diagnostics should be <expected_diag_count>
    And the returned BodyContent should be: <expected_content_json>
    And the remaining BodyContent in the MockBody should be: <remaining_content_json>

    Examples:
      | initial_content_json                           | attrs_schema_json              | blocks_schema_json               | expected_diag_count | expected_content_json                        | remaining_content_json                       |
      | `{}`                                           | `[]`                           | `[]`                             | 0                   | `{"Attributes":{},"Blocks":[]}`              | `{"Attributes":{},"Blocks":[]}`              | # empty
      | `{"Attributes":{"name":"MEL(Str(E))"}}`        | `[{"Name":"name"}]`            | `[]`                             | 0                   | `{"Attributes":{"name":"MEL(Str(E))"},"Blocks":[]}` | `{"Attributes":{},"Blocks":[]}`              | # attribute requested
      | `{"Attributes":{"name":"MEL(Str(E))"}}`        | `[]`                           | `[]`                             | 0                   | `{"Attributes":{},"Blocks":[]}`              | `{"Attributes":{"name":"MEL(Str(E))"},"Blocks":[]}` | # attribute remains
      | `{}`                                           | `[{"Name":"name","Required":true}]` | `[]`                           | 1                   | `{"Attributes":{},"Blocks":[]}`              | `{"Attributes":{},"Blocks":[]}`              | # attribute missing (diag: "Missing required argument")
      | `{"Blocks":[{"Type":"baz"}]}`                  | `[]`                           | `[{"Type":"baz"}]`               | 0                   | `{"Attributes":{},"Blocks":[{"Type":"baz"}]}` | `{"Attributes":{},"Blocks":[]}`              | # block requested, no labels
      | `{"Blocks":[{"Type":"baz"}]}`                  | `[]`                           | `[{"Type":"baz","LabelNames":["foo"]}]` | 1                | `{"Attributes":{},"Blocks":[{"Type":"baz"}]}` | `{"Attributes":{},"Blocks":[]}`              | # block requested, wrong labels (diag: "Wrong number of block labels")
      | `{"Attributes":{"name":"MEL(Str(E))","age":"MEL(Num(32))"},"Blocks":[{"Type":"baz"},{"Type":"bar","Labels":["f1"]},{"Type":"bar","Labels":["f2"]}]}` | `[{"Name":"name"}]` | `[{"Type":"bar","LabelNames":["name"]}]` | 0 | `{"Attributes":{"name":"MEL(Str(E))"},"Blocks":[{"Type":"bar","Labels":["f1"]},{"Type":"bar","Labels":["f2"]}]}` | `{"Attributes":{"age":"MEL(Num(32))"},"Blocks":[{"Type":"baz"}]}` | # various

  Scenario Outline: MockBody Content method (non-partial)
    Given a MockBody created with initial content: <initial_content_json>
    And a BodySchema defined with Attributes: <attrs_schema_json> and Blocks: <blocks_schema_json>
    When `Content` is called on the MockBody with the schema
    Then the number of diagnostics should be <expected_diag_count>
    And the returned BodyContent should be: <expected_content_json>
    And if diagnostics are expected, the first summary should contain "<expected_error_summary_contains>"

    Examples:
      | initial_content_json               | attrs_schema_json | blocks_schema_json | expected_diag_count | expected_content_json           | expected_error_summary_contains   |
      | `{"Attributes":{"a":"MEL(1)"}}`    | `[{"Name":"a"}]`  | `[]`               | 0                   | `{"Attributes":{"a":"MEL(1)"}}`  |                                   |
      | `{"Attributes":{"a":"MEL(1)"}}`    | `[]`              | `[]`               | 1                   | `{"Attributes":{}}`             | "Extraneous argument"             | # Extraneous attr
      | `{"Blocks":[{"Type":"foo"}]}`      | `[]`              | `[]`               | 1                   | `{"Attributes":{},"Blocks":[]}` | "Extraneous block"                | # Extraneous block

  Scenario Outline: MockBody JustAttributes method
    Given a MockBody created with initial content: <initial_content_json>
    When `JustAttributes` is called on the MockBody
    Then the number of diagnostics should be <expected_diag_count>
    And the returned hcl.Attributes map should be: <expected_attrs_map_json>
    And if diagnostics are expected, the first summary should contain "<expected_error_summary_contains>"

    Examples:
      | initial_content_json               | expected_diag_count | expected_attrs_map_json   | expected_error_summary_contains |
      | `{}`                               | 0                   | `{}`                      |                                 |
      | `{"Attributes":{"a":"MEL(1)"}}`    | 0                   | `{"a":"MEL(1)"}`          |                                 |
      | `{"Blocks":[{"Type":"foo"}]}`      | 1                   | `{}`                      | "Mock body has blocks"          |

  Scenario Outline: Using MockExprLiteral with hcl.ExprList and hcl.ExprMap
    Given a `MockExprLiteral` created from the cty.Value: <input_cty_value_repr>
    When <hcl_helper_function> is called with this mock expression
    Then the result should be <expected_result_repr>
    And if an error is expected, the diagnostics should contain "<expected_error_message>"

    Examples:
      | input_cty_value_repr        | hcl_helper_function | expected_result_repr                                | expected_error_message      |
      | `ListVal([Str(f),Str(b)])`  | hcl.ExprList        | `[MEL(Str(f)), MEL(Str(b))]`                        |                             |
      | `TupleVal([Str(f),Str(b)])` | hcl.ExprList        | `[MEL(Str(f)), MEL(Str(b))]`                        |                             |
      | `ObjectVal({a:Str(f)})`     | hcl.ExprList        | `(nil)`                                             | "list expression is required" |
      | `ObjectVal({n:Str(t),c:N(2)})`| hcl.ExprMap         | `[{K:MEL(Str(c)),V:MEL(N(2))},{K:MEL(Str(n)),V:MEL(Str(t))}]` |                       | # Order may vary
      | `MapVal({n:Str(t),v:Str(2)})` | hcl.ExprMap         | `[{K:MEL(Str(n)),V:MEL(Str(t))},{K:MEL(Str(v)),V:MEL(Str(2))}]` |                       | # Order may vary
      | `ListVal([Str(f),Str(b)])`  | hcl.ExprMap         | `(nil)`                                             | "map expression is required"  |

  Scenario Outline: MockExprVariable behavior
    Given a `MockExprVariable` for variable name "<var_name>"
    When its `Value()` method is called with an EvalContext <context_description>
    Then the resulting cty.Value should be <expected_value_repr>
    And if a diagnostic is expected, its summary should be "<expected_diag_summary>"
    When its `Variables()` method is called
    Then it should return a list containing one traversal for "<var_name>"
    When its `AsTraversal()` method is called
    Then it should return an absolute traversal for "<var_name>"

    Examples:
      | var_name | context_description                          | expected_value_repr | expected_diag_summary           |
      | "foo"    | `with var "foo" = StringVal("bar")`          | `StringVal("bar")`  |                                 |
      | "foo"    | `with var "other" = StringVal("baz")`        | `DynamicVal`        | "Reference to undefined variable" |
      | "foo"    | `with parent context having "foo" = Str("p")`| `StringVal("p")`    |                                 |

  Scenario Outline: MockExprTraversal behavior
    Given a `MockExprTraversal` created for traversal "<traversal_string>"
    When its `Value()` method is called with an EvalContext <context_description>
    Then the resulting cty.Value should be <expected_value_repr>
    When its `Variables()` method is called
    Then it should return a list containing the traversal for "<traversal_string>"
    When its `AsTraversal()` method is called
    Then it should return the traversal for "<traversal_string>"

    Examples:
      | traversal_string | context_description                      | expected_value_repr |
      | "foo.bar"        | `with var "foo"=ObjVal({bar:Str("baz")})`| `StringVal("baz")`  |

  Scenario: MockExprList behavior
    Given a `MockExprList` created with element expressions [MockExprLiteral(NumberIntVal(1)), MockExprVariable("myVar")]
    And an EvalContext with variable "myVar" = StringVal("test")
    When its `Value()` method is called with the EvalContext
    Then the resulting cty.Value should be ListVal([NumberIntVal(1), StringVal("test")])
    When its `Variables()` method is called
    Then it should return a list containing one traversal for "myVar"

    # Notes for tables:
    # - JSON-like representations are simplified. `MEL(Str(E))` means MockExprLiteral(cty.StringVal("Ermintrude")). `Num(1)` means NumberIntVal(1).
    # - `(nil)` for expected_result_repr means the Go slice/map is nil.
    # - For `hcl.ExprMap` results, the order of KeyValuePairs from object/map literals is not guaranteed.
    # - `context_description` for MockExprVariable/MockExprTraversal simplifies EvalContext setup.
    # - `expected_value_repr` is a cty.Value string representation.
