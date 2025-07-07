# Covers gohcl.ImpliedBodySchema function in ./gohcl/schema.go
# Based on test cases in ./gohcl/schema_test.go (TestImpliedBodySchema)
# and analysis of schema.go for tag parsing logic and panic conditions.

Feature: gohcl - Implied HCL Body Schema from Go Struct Tags
  This feature tests the `gohcl.ImpliedBodySchema` function, which infers an
  `hcl.BodySchema` from a Go struct type based on its `hcl:` field tags.
  This schema is then used for decoding HCL configurations into the struct.

  Scenario Outline: Deriving HCL Body Schema from various Go struct definitions
    Given a Go struct value defined as: <go_struct_type_description>
      And its fields are tagged as follows: <hcl_tags_description>
    When `gohcl.ImpliedBodySchema` is called with this struct value
    Then the returned `hcl.BodySchema` should have Attributes: <expected_attributes_schema_repr>
    And the returned `hcl.BodySchema` should have Blocks: <expected_blocks_schema_repr>
    And the returned 'partial' flag should be <expected_partial_flag>

    Examples:
      | go_struct_type_description | hcl_tags_description                                     | expected_attributes_schema_repr        | expected_blocks_schema_repr              | expected_partial_flag |
      | `struct{}`                 | (no tags)                                                | `[]`                                   | `[]`                                     | false                 |
      | `struct{ Ignored bool }`   | (no hcl tag)                                             | `[]`                                   | `[]`                                     | false                 |
      | `struct{ A bool; B bool }` | `A:"attr1", B:"attr2"`                                   | `[{N:attr1,R:true},{N:attr2,R:true}]`  | `[]`                                     | false                 |
      | `struct{ Attr *bool }`    | `Attr:"attr,attr"`                                       | `[{N:attr,R:false}]`                   | `[]`                                     | false                 | # Pointer is optional
      | `struct{ Thing struct{} }` | `Thing:"thing,block"`                                    | `[]`                                   | `[{T:thing}]`                            | false                 |
      | `struct{ Thing struct{Type string \`hcl:"type,label"\`; Name string \`hcl:"name,label"\`} }` | `Thing:"thing,block"` | `[]`                                   | `[{T:thing,L:["type","name"]}]`          | false                 | # Block with labels
      | `struct{ Thing []struct{Type string \`hcl:"type,label"\`} }` | `Thing:"thing,block"`    | `[]`                                   | `[{T:thing,L:["type"]}]`                 | false                 | # Slice of blocks
      | `struct{ Doodad string; Thing struct{Name string \`hcl:"name,label"\`} }` | `Doodad:"doodad", Thing:"thing,block"` | `[{N:doodad,R:true}]`                | `[{T:thing,L:["name"]}]`                 | false                 | # Mixed attrs and blocks
      | `struct{ Doodad string; Config string }` | `Doodad:"doodad", Config:",remain"`                | `[{N:doodad,R:true}]`                | `[]`                                     | true                  | # Remain tag
      | `struct{ Expr hcl.Expression }` | `Expr:"expr"`                                            | `[{N:expr,R:false}]`                   | `[]`                                     | false                 | # hcl.Expression is optional
      | `struct{ Meh string }`      | `Meh:"meh,optional"`                                     | `[{N:meh,R:false}]`                    | `[]`                                     | false                 | # Explicit optional

  Scenario Outline: gohcl.ImpliedBodySchema panics for invalid struct definitions or tags
    Given a Go struct value defined as: <go_struct_type_description>
      And its fields are tagged as follows: <hcl_tags_description>
    When `gohcl.ImpliedBodySchema` is called with this struct value
    Then the operation should panic with a message containing "<expected_panic_substring>"

    Examples:
      | go_struct_type_description      | hcl_tags_description                                  | expected_panic_substring                                     |
      | `int` (not a struct)            | (n/a)                                                 | "given value must be struct, not int"                        |
      | `struct{ F1 string; F2 int }`  | `F1:",remain", F2:",remain"`                          | "only one 'remain' tag is permitted"                         |
      | `struct{ F1 hcl.Body; F2 hcl.Body }` | `F1:",body", F2:",body"`                           | "only one 'body' tag is permitted"                           |
      | `struct{ B int }`               | `B:"name,block"`                                      | "hcl 'block' tag kind cannot be applied to int field"        |
      | `struct{ F string }`           | `F:"name,unknownkind"`                                | "invalid hcl field tag kind \"unknownkind\""                 |
      | `struct{ DR1 Range; DR2 Range}` | `DR1:",def_range", DR2:",def_range"`                  | "only one 'def_range' tag is permitted"                      |
      | `struct{ TR1 Range; TR2 Range}` | `TR1:",type_range", TR2:",type_range"`                | "only one 'type_range' tag is permitted"                     |

    # Notes for table representation:
    # - `go_struct_type_description`: A simplified string describing the Go struct.
    # - `hcl_tags_description`: Describes the `hcl:` tags on fields, e.g., `FieldName:"hcl_name,kind"`.
    # - `expected_attributes_schema_repr`: List of `{N:Name,R:Required}` for hcl.AttributeSchema. `[]` for empty.
    # - `expected_blocks_schema_repr`: List of `{T:Type,L:[Labels]}` for hcl.BlockHeaderSchema. `[]` for empty.
    # - `Range` refers to `hcl.Range`.
    # - The panic scenarios are based on the logic in the unexported `getFieldTags` function.
