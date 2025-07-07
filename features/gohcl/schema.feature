# Covers tests in ./gohcl/schema_test.go
# Specifically, TestImpliedBodySchema

Feature: gohcl - Implied HCL Body Schema from Go Structs
  This feature tests the `ImpliedBodySchema` function from the `gohcl` package,
  which infers an `hcl.BodySchema` from a given Go struct type based on its
  field tags.

  Scenario Outline: Deriving HCL Body Schema from Go struct definition
    Given a Go struct defined as: <go_struct_definition>
    When `ImpliedBodySchema` is called with an instance of this struct
    Then the returned `hcl.BodySchema` should have attributes: <expected_attributes_schema>
    And the returned `hcl.BodySchema` should have blocks: <expected_blocks_schema>
    And the returned 'partial' flag should be <expected_partial_flag>

    Examples:
      | go_struct_definition                                       | expected_attributes_schema              | expected_blocks_schema                         | expected_partial_flag |
      | `struct{}`                                                 | (empty)                                 | (empty)                                        | false                 |
      | `struct { Ignored bool }`                                  | (empty)                                 | (empty)                                        | false                 | # Un-tagged field is ignored
      | `struct { Attr1 bool \`hcl:"attr1"\`; Attr2 bool \`hcl:"attr2"\` }` | [{N:"attr1",R:true},{N:"attr2",R:true}] | (empty)                                        | false                 | # Basic attributes
      | `struct { Attr *bool \`hcl:"attr,attr"\` }`                   | [{N:"attr",R:false}]                    | (empty)                                        | false                 | # Pointer attribute is optional by default (tag "attr" is for attribute name)
      | `struct { Thing struct{} \`hcl:"thing,block"\` }`              | (empty)                                 | [{T:"thing"}]                                  | false                 | # Basic block
      | `struct { Thing struct { Type string \`hcl:"type,label"\`; Name string \`hcl:"name,label"\` } \`hcl:"thing,block"\` }` | (empty)                         | [{T:"thing",L:["type","name"]}]                | false                 | # Block with labels
      | `struct { Thing []struct { Type string \`hcl:"type,label"\`; Name string \`hcl:"name,label"\` } \`hcl:"thing,block"\` }` | (empty)                       | [{T:"thing",L:["type","name"]}]                | false                 | # Slice of blocks with labels
      | `struct { Thing *struct { Type string \`hcl:"type,label"\`; Name string \`hcl:"name,label"\` } \`hcl:"thing,block"\` }` | (empty)                       | [{T:"thing",L:["type","name"]}]                | false                 | # Pointer to block with labels
      | `struct { Thing struct { Name string \`hcl:"name,label"\`; Something string \`hcl:"something"\` } \`hcl:"thing,block"\` }` | (empty)                     | [{T:"thing",L:["name"]}]                       | false                 | # Block with one label and one inner attribute
      | `struct { Doodad string \`hcl:"doodad"\`; Thing struct { Name string \`hcl:"name,label"\` } \`hcl:"thing,block"\` }` | [{N:"doodad",R:true}]           | [{T:"thing",L:["name"]}]                       | false                 | # Mixed attribute and block
      | `struct { Doodad string \`hcl:"doodad"\`; Config string \`hcl:",remain"\` }` | [{N:"doodad",R:true}]           | (empty)                                        | true                  | # Remain tag makes schema partial
      | `struct { Expr hcl.Expression \`hcl:"expr"\` }`             | [{N:"expr",R:false}]                    | (empty)                                        | false                 | # hcl.Expression field is an optional attribute
      | `struct { Meh string \`hcl:"meh,optional"\` }`               | [{N:"meh",R:false}]                     | (empty)                                        | false                 | # Explicitly optional attribute

    # Notes for schema representation:
    # - (empty) means an empty slice or map.
    # - Attributes schema: [{N:"name",R:true/false}] where N is Name, R is Required.
    # - Blocks schema: [{T:"type",L:["label1","label2"]}] where T is Type, L is LabelNames slice.
    # - `hcl:"name,attr"` is equivalent to `hcl:"name"` for attributes.
    # - `hcl:"name,block"` denotes a block.
    # - `hcl:"name,label"` denotes a label for a block.
    # - `hcl:",remain"` denotes a catch-all for remaining attributes/blocks.
    # - `hcl:"name,optional"` makes an attribute optional. Pointers and hcl.Expression are implicitly optional.
