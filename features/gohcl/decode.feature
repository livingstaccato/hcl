# Covers tests in ./gohcl/decode_test.go
# Specifically, TestDecodeBody and TestDecodeExpression

Feature: gohcl - Decoding HCL into Go Structs and Values
  This feature tests the `DecodeBody` and `DecodeExpression` functions from
  the `gohcl` package, which decode HCL constructs into Go data structures.

  Scenario Outline: Decoding HCL Body into various Go struct types
    Given an HCL body represented by the JSON: <json_body>
    And a target Go struct of type <target_go_type_description> (initially <initial_state_description>)
    When `DecodeBody` is called with the HCL body, nil context, and a pointer to the target struct instance
    Then the number of diagnostics should be <expected_diag_count>
    And the decoded target struct should satisfy: <check_description>

    Examples:
      | json_body                                  | target_go_type_description | initial_state_description | expected_diag_count | check_description                                                                 |
      | `{}`                                       | `struct{}`                 | empty                     | 0                   | Is `struct{}`                                                                     |
      | `{}`                                       | `struct{ Name string }`     | empty                     | 1                   | Is `struct{ Name string }` (Name is zero value)                                   | # Name required
      | `{}`                                       | `struct{ Name *string }`    | empty                     | 0                   | Name is nil                                                                       |
      | `{}`                                       | `struct{ Name string \`hcl:"name,optional"\` }` | empty    | 0                   | Is `struct{ Name string }` (Name is zero value)                                   |
      | `{}`                                       | `withNameExpression`       | empty                     | 0                   | Name hcl.Expression evaluates to null                                             |
      | `{"name": "Ermintrude"}`                   | `withNameExpression`       | empty                     | 0                   | Name hcl.Expression evaluates to "Ermintrude"                                     |
      | `{"name": "Ermintrude"}`                   | `struct{ Name string }`     | empty                     | 0                   | Name is "Ermintrude"                                                              |
      | `{"name": "Ermintrude", "age": 23}`        | `struct{ Name string }`     | empty                     | 1                   | Name is "Ermintrude"                                                              | # Extraneous "age"
      | `{"name": "Ermintrude", "age": 50}`        | `struct{ Name string, Attrs hcl.Attributes \`hcl:",remain"\` }` | empty | 0      | Name is "Ermintrude", Attrs has 1 entry "age"                                     |
      | `{"name": "Ermintrude", "age": 50}`        | `struct{ Name string, Remain hcl.Body \`hcl:",remain"\` }` | empty      | 0      | Name is "Ermintrude", Remain body has attribute "age"                             |
      | `{"name": "Ermintrude", "living": true}`   | `struct{ Name string, Remain map[string]cty.Value \`hcl:",remain"\` }` | empty | 0 | Name is "Ermintrude", Remain map is {"living": cty.True}                          |
      | `{"name": "Ermintrude", "age": 50}`        | `struct{ Name string, Body hcl.Body \`hcl:",body"\`, Remain hcl.Body \`hcl:",remain"\` }` | empty | 0 | Name is "Ermintrude", Body has attributes "name" and "age"                      |
      | `{"noodle": {}}`                           | `struct{ Noodle struct{} \`hcl:"noodle,block"\` }` | empty    | 0                   | Decoded successfully (struct is present)                                          |
      | `{"noodle": [{}]}`                         | `struct{ Noodle struct{} \`hcl:"noodle,block"\` }` | empty    | 0                   | Decoded successfully (struct is present)                                          |
      | `{"noodle": [{}, {}]}`                     | `struct{ Noodle struct{} \`hcl:"noodle,block"\` }` | empty    | 1                   | Decoded (but one block too many for single struct)                                |
      | `{}`                                       | `struct{ Noodle struct{} \`hcl:"noodle,block"\` }` | empty    | 1                   | Decoded (block required)                                                          |
      | `{"noodle": []}`                           | `struct{ Noodle struct{} \`hcl:"noodle,block"\` }` | empty    | 1                   | Decoded (block required, empty list doesn't satisfy)                            |
      | `{"noodle": {}}`                           | `struct{ Noodle *struct{} \`hcl:"noodle,block"\` }`| empty    | 0                   | Noodle pointer is not nil                                                         |
      | `{"noodle": [{}]}`                         | `struct{ Noodle *struct{} \`hcl:"noodle,block"\` }`| empty    | 0                   | Noodle pointer is not nil                                                         |
      | `{"noodle": []}`                           | `struct{ Noodle *struct{} \`hcl:"noodle,block"\` }`| empty    | 0                   | Noodle pointer is nil (optional block not present)                                |
      | `{"noodle": [{}, {}]}`                     | `struct{ Noodle *struct{} \`hcl:"noodle,block"\` }`| empty    | 1                   | Decoded (but one block too many for single pointer struct)                        |
      | `{"noodle": []}`                           | `struct{ Noodle []struct{} \`hcl:"noodle,block"\` }`| empty   | 0                   | Noodle slice has length 0                                                         |
      | `{"noodle": [{}]}`                         | `struct{ Noodle []struct{} \`hcl:"noodle,block"\` }`| empty   | 0                   | Noodle slice has length 1                                                         |
      | `{"noodle": [{}, {}]}`                     | `struct{ Noodle []struct{} \`hcl:"noodle,block"\` }`| empty   | 0                   | Noodle slice has length 2                                                         |
      | `{"noodle": {}}`                           | `struct{ Noodle struct{Name string \`hcl:"name,label"\`} \`hcl:"noodle,block"\` }` | empty | 2 | Decoded (missing label, and JSON structure implies missing label level)         |
      | `{"noodle": {"foo_foo":{}}}`               | `struct{ Noodle struct{Name string \`hcl:"name,label"\`} \`hcl:"noodle,block"\` }` | empty | 0 | Noodle.Name is "foo_foo"                                                        |
      | `{"noodle": {"foo_foo":{},"bar_baz":{}}}`  | `struct{ Noodle struct{Name string \`hcl:"name,label"\`} \`hcl:"noodle,block"\` }` | empty | 1 | Decoded (multiple blocks for single struct)                                     |
      | `{"noodle": {"foo_foo":{},"bar_baz":{}}}`  | `struct{ Noodles []struct{Name string \`hcl:"name,label"\`} \`hcl:"noodle,block"\` }` | empty | 0 | Noodles slice has 2 elements, names are "foo_foo" and "bar_baz" (any order)   |
      | `{"noodle": {"foo_foo":{"type":"rice"}}}`  | `struct{ Noodle struct{Name string \`hcl:"name,label"\`, Type string} \`hcl:"noodle,block"\` }` | empty | 0 | Noodle.Name is "foo_foo", Noodle.Type is "rice"                               |
      | `{"name":"Ermintrude", "age":34}`          | `map[string]string`        | empty                     | 0                   | Map is `{"name":"Ermintrude", "age":"34"}`                                        |
      | `{"name":"Ermintrude", "age":89}`          | `map[string]*hcl.Attribute`| empty                     | 0                   | Map has 2 entries "name" and "age", values are non-nil hcl.Attribute pointers |
      | `{"name":"Ermintrude", "age":13}`          | `map[string]hcl.Expression`| empty                     | 0                   | Map has 2 entries "name" and "age", values are non-nil hcl.Expression           |
      | `{"name":"Ermintrude", "living":true}`     | `map[string]cty.Value`     | empty                     | 0                   | Map is `{"name":cty.StringVal("Ermintrude"), "living":cty.True}`                  |
      | `{"plain": "foo"}`                         | `withNestedBlock`          | Plain:"bar", Nested:{A:"bar"} | 0                 | Plain is "foo", Nested.A is "bar"                                                 | # Retain nested block
      | `{"nested": {"a": "foo"}}`                 | `withNestedBlock`          | Nested:{B:"bar"}          | 0                   | Nested.A is "foo", Nested.B is "bar"                                              | # Retain values in nested
      | `{"nested": [{"a":"foo"}]}`                | `withListofNestedBlocks`   | Nested:[{B:"bar"}]        | 0                   | Nested[0].A is "foo", Nested[0].B is "bar"                                        | # Retain values in list of nested
      | `{"nested": [{"a":"foo"}]}`                | `withListofNestedBlocks`   | Nested:[{B:"bar"},{B:"bar"}] | 0                 | Nested slice has length 1 (extra elements removed)                                |
      | `{"nested": [{"b":"bar"},{"b":"baz"}]}`    | `withListofNestedBlocksNoPointers` | Nested:[{B:"foo"}] | 0                 | Nested[0].B is "bar", Nested slice has length 2                                   |
      | `{"foo":{"foo_type":{"foo_name":{"value":"foo"}}}}` | `struct_with_ranges` | empty                   | 0                   | All range fields are populated correctly (see Go test for exact ranges)           |

  Scenario Outline: Decoding HCL Expression into various Go types
    Given an HCL expression that evaluates to cty.Value <cty_value>
    And a target Go variable of type <target_go_type>
    When `DecodeExpression` is called with the expression, nil context, and a pointer to the target variable
    Then the number of diagnostics should be <expected_diag_count>
    And the decoded target variable should be <expected_go_value>

    Examples:
      | cty_value                      | target_go_type | expected_go_value | expected_diag_count |
      | `cty.StringVal("hello")`       | `string`       | `"hello"`         | 0                   |
      | `cty.StringVal("hello")`       | `cty.Value`    | `cty.StringVal("hello")` | 0            |
      | `cty.NumberIntVal(2)`          | `string`       | `"2"`             | 0                   |
      | `cty.StringVal("true")`        | `bool`         | `true`            | 0                   |
      | `cty.NullVal(cty.String)`      | `string`       | `""`              | 1                   | # null not allowed
      | `cty.UnknownVal(cty.String)`   | `string`       | `""`              | 1                   | # unknown not allowed
      | `cty.ListVal([cty.True])`      | `bool`         | `false`           | 1                   | # bool required

    # Notes for tables:
    # - `withNameExpression` is `struct{ Name hcl.Expression \`hcl:"name"\` }`
    # - `withNestedBlock` is `struct{ Plain string \`hcl:"plain,optional"\`, Nested *withTwoAttributes \`hcl:"nested,block"\` }`
    #   where `withTwoAttributes` is `struct{ A string \`hcl:"a,optional"\`, B string \`hcl:"b,optional"\` }`
    # - `withListofNestedBlocks` is `struct{ Nested []*withTwoAttributes \`hcl:"nested,block"\` }`
    # - `withListofNestedBlocksNoPointers` is `struct{ Nested []withTwoAttributes \`hcl:"nested,block"\` }`
    # - `struct_with_ranges` refers to the complex struct in the last Go test case for DecodeBody, checking various range fields.
    # - `cty.Value` representations are illustrative.
    # - Initial state description for structs is simplified.
    # - Check description for structs is simplified. For maps, it's the expected map content.
    # - For `struct_with_ranges`, the check is that all specific range fields (TypeLabelRange, NameLabelRange, DefRange, TypeRange, AttributeRange, etc.) are correctly populated according to the JSON structure. Exact byte/line/column values are in the Go test.
