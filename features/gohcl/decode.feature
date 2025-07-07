# Covers functions in ./gohcl/decode.go
# Based on test cases in ./gohcl/decode_test.go (TestDecodeBody, TestDecodeExpression)

Feature: gohcl - Decoding HCL into Go Data Structures
  This feature tests the `gohcl.DecodeBody` and `gohcl.DecodeExpression` functions,
  which facilitate decoding HCL configurations (bodies and expressions) directly
  into Go native data types, primarily structs and maps, using struct field tags
  for mapping.

  Scenario Outline: Decoding HCL Body into various Go struct types using gohcl.DecodeBody
    Given an HCL body parsed from JSON: <json_body_for_hcl_content>
      # JSON is used in tests for convenient HCL body construction.
    And a target Go struct instance of type <target_go_type_description>
    And an optional initial state for the target struct: <initial_struct_state_json>
    And an optional `hcl.EvalContext` "Ctx" <eval_context_setup>
    When `gohcl.DecodeBody` is called with the HCL body, "Ctx", and a pointer to the target struct
    Then the number of diagnostics should be <expected_diag_count>
    And the fields of the decoded target struct should match: <expected_struct_fields_json>
    And if diagnostics are expected, the first relevant diagnostic summary should contain "<expected_error_summary_contains>"

    Examples:
      # Basic Attributes
      | json_body_for_hcl_content | target_go_type_description | initial_struct_state_json | eval_context_setup | expected_diag_count | expected_struct_fields_json | expected_error_summary_contains |
      | `{}`                      | `struct{}`                 | `{}`                      | (nil)              | 0                   | `{}`                        |                                 |
      | `{}`                      | `struct{Name string \`hcl:"name"\`}` | `{}`                   | (nil)              | 1                   | `{"Name":""}`               | "Missing required attribute 'name'" |
      | `{}`                      | `struct{Name *string \`hcl:"name"\`}`| `{}`                   | (nil)              | 0                   | `{"Name":null}`             |                                 |
      | `{"name":"E"}`            | `struct{Name string \`hcl:"name"\`}` | `{}`                   | (nil)              | 0                   | `{"Name":"E"}`              |                                 |
      | `{"name":"E", "age":23}`  | `struct{Name string \`hcl:"name"\`}` | `{}`                   | (nil)              | 1                   | `{"Name":"E"}`              | "Unsupported argument"          | # Extraneous "age"
      # Remain and Body Tags
      | `{"name":"E", "age":50}`  | `struct{Name string \`hcl:"name"\`; Attrs hcl.Attributes \`hcl:",remain"\`}` | `{}` | (nil) | 0       | `{"Name":"E", "Attrs":{"age": AttributeExpr}}` |                           |
      | `{"name":"E", "age":50}`  | `struct{Name string \`hcl:"name"\`; Remain hcl.Body \`hcl:",remain"\`}`    | `{}` | (nil) | 0       | `{"Name":"E", "Remain": BodyWithAttrAge}`     |                           |
      | `{"name":"E", "living":true}` | `struct{Name string \`hcl:"name"\`; Remain map[string]cty.Value \`hcl:",remain"\`}` | `{}` | (nil) | 0 | `{"Name":"E", "Remain":{"living":true}}` |                           |
      | `{"name":"E", "age":50}`  | `struct{Name string \`hcl:"name"\`; Body hcl.Body \`hcl:",body"\`; Remain hcl.Body \`hcl:",remain"\`}` | `{}` | (nil) | 0 | `{"Name":"E", "Body": BodyWithNameAge, "Remain": BodyWithAttrAge}` |       |
      # Blocks (single, slice, pointer, labels)
      | `{"noodle":{}}`           | `struct{Noodle struct{} \`hcl:"noodle,block"\`}` | `{}`            | (nil)         | 0                   | `{"Noodle":{}}`             |                                 |
      | `{"noodle":[{"a":"v1"},{"a":"v2"}]}` | `struct{Noodle []struct{A string \`hcl:"a"\`} \`hcl:"noodle,block"\`}` | `{}` | (nil) | 0     | `{"Noodle":[{"A":"v1"},{"A":"v2"}]}` |                                 |
      | `{"noodle":{"lbl":{"type":"rice"}}}` | `struct{Noodle struct{Name string \`hcl:"name,label"\`; Type string} \`hcl:"noodle,block"\`}` | `{}` | (nil) | 0 | `{"Noodle":{"Name":"lbl","Type":"rice"}}` |                       |
      | `{"noodle":{"L1":{},"L2":{}}}` | `struct{Noodles []struct{Name string \`hcl:"name,label"\`} \`hcl:"noodle,block"\`}` | `{}` | (nil) | 0 | `{"Noodles":[{"Name":"L1"},{"Name":"L2"}]}` (order may vary) |       |
      # Decoding into Maps
      | `{"name":"E","age":34}`   | `map[string]string`        | `{}`                      | (nil)              | 0                   | `{"name":"E","age":"34"}`   |                                 |
      | `{"name":"E","age":89}`   | `map[string]*hcl.Attribute`| `{}`                      | (nil)              | 0                   | `{"name":AttrExpr,"age":AttrExpr}` |                            |
      # Retaining existing struct values
      | `{"plain":"foo"}`         | `struct Plain string \`hcl:"plain,optional"\`; Nested *struct{A string \`hcl:"a"\`} \`hcl:"nested,block"\` }` | `{"Plain":"bar", "Nested":{"A":"bar"}}` | (nil) | 0 | `{"Plain":"foo", "Nested":{"A":"bar"}}` |    |
      # Range capture tags
      | `{"foo":{"ft":{"fn":{"value":"v"}}}}` | (struct_with_all_range_tags) | `{}` | (nil) | 0 | (struct_with_all_ranges_populated) | |

  Scenario Outline: Decoding HCL Expression into various Go types using gohcl.DecodeExpression
    Given an `hcl.Expression` "InputExpr" that evaluates to cty.Value <input_cty_value_repr>
    And a target Go variable of type <target_go_type>
    When `gohcl.DecodeExpression` is called with "InputExpr", nil context, and a pointer to the target variable
    Then the number of diagnostics should be <expected_diag_count>
    And the decoded target variable should have the value <expected_go_value_repr> (type-dependent representation)
    And if diagnostics are expected, the first summary should be "<expected_error_summary>"

    Examples:
      | input_cty_value_repr      | target_go_type | expected_go_value_repr | expected_diag_count | expected_error_summary   |
      | `StringVal("hello")`      | `string`       | `"hello"`              | 0                   |                          |
      | `StringVal("hello")`      | `cty.Value`    | `StringVal("hello")`   | 0                   |                          |
      | `NumberIntVal(2)`         | `string`       | `"2"`                  | 0                   |                          | # Conversion
      | `StringVal("true")`       | `bool`         | `true`                 | 0                   |                          | # Conversion
      | `NullVal(cty.String)`     | `string`       | `""` (zero value)      | 1                   | "Unsuitable value type"  | # Null not allowed for basic string
      | `UnknownVal(cty.String)`  | `string`       | `""` (zero value)      | 1                   | "Unsuitable value type"  | # Unknown not allowed
      | `ListVal([cty.True])`     | `bool`         | `false` (zero value)   | 1                   | "Unsuitable value type"  | # List to bool fails

    # Notes for tables:
    # - JSON representations are simplified. `MEL(Str(E))` means MockExprLiteral(cty.StringVal("Ermintrude")).
    # - `eval_context_setup`: (nil) or specific variable/function setup.
    # - `expected_struct_fields_json`: JSON representation of expected field values. `null` for nil pointers.
    #   `AttributeExpr` means a non-nil *hcl.Attribute. `BodyWithAttrAge` means an hcl.Body containing that attribute.
    # - `(struct_with_all_range_tags)` and `(struct_with_all_ranges_populated)` refer to the complex struct in TestDecodeBody for range checking.
    #   The BDD step implies verification of all specific hcl.Range fields.
    # - `input_cty_value_repr` and `expected_go_value_repr` are simplified representations.
    # - `(zero value)` means the Go zero value for that type.
