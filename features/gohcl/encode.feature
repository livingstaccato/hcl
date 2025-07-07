# Covers functions in ./gohcl/encode.go
# Based on ExampleEncodeIntoBody in ./gohcl/encode_test.go and analysis of encode.go

Feature: gohcl - Encoding Go Structs into HCL
  This feature tests the `gohcl.EncodeIntoBody` and `gohcl.EncodeAsBlock` functions,
  which serialize Go structs (using `hcl:` tags) into an `hclwrite.Body` or
  `hclwrite.Block` respectively, suitable for generating HCL configuration files.

  Scenario: Encoding a complex nested Go struct into an HCL Body (EncodeIntoBody)
    Given Go struct definitions for `App`, `Service` (with `name,label` and `executable` attr), and `Constraints` (with `os`, `arch` attrs)
    And an `App` instance populated with:
      Name: "awesome-app"
      Desc: "Such an awesome application"
      Constraints (pointer): {OS: "linux", Arch: "amd64"}
      Services (slice):
        - {Name: "web", Exe: ["./web", "--listen=:8080"]}
        - {Name: "worker", Exe: ["./worker"]}
    And an empty `hclwrite.File` "f"
    When `gohcl.EncodeIntoBody` is called with the `App` instance and `f.Body()`
    Then the HCL content of `f.Bytes()` should be:
      """
      name        = "awesome-app"
      description = "Such an awesome application"

      constraints {
        os   = "linux"
        arch = "amd64"
      }

      service "web" {
        executable = ["./web", "--listen=:8080"]
      }
      service "worker" {
        executable = ["./worker"]
      }
      """

  Scenario Outline: Encoding a Go struct into an HCL Block (EncodeAsBlock)
    Given a Go struct <struct_type_description> defined with fields: <fields_with_tags_json>
      # e.g., `{"Name":"hcl:\"name,label\"", "Port":"hcl:\"port,attr\""}`
    And an instance of this struct "DataInstance" populated with: <instance_data_json>
      # e.g., `{"Name":"my-service", "Port":80}`
    When `gohcl.EncodeAsBlock` is called with "DataInstance" and block type "<block_type_name>"
    Then the resulting `hclwrite.Block` when serialized to HCL string should be:
      """
      <expected_hcl_block_string>
      """

    Examples:
      | struct_type_description | fields_with_tags_json                                      | instance_data_json         | block_type_name | expected_hcl_block_string        |
      | SimpleBlock             | `{"Config":"hcl:\"config\""}`                              | `{"Config":"value"}`       | "simple"        | `simple {\n  config = "value"\n}` | # No labels
      | LabeledBlock            | `{"Type":"hcl:\"type,label\"", "Setting":"hcl:\"setting\""}` | `{"Type":"nginx","Setting":true}` | "resource"      | `resource "nginx" {\n  setting = true\n}` | # One label
      | MultiLabeledBlock       | `{"Kind":"hcl:\"kind,label\"","Name":"hcl:\"name,label\"","ID":"hcl:\"id\""}` | `{"Kind":"db","Name":"main","ID":123}` | "item"       | `item "db" "main" {\n  id = 123\n}` | # Two labels

  Scenario Outline: Encoding behavior with optional fields and special tags (EncodeIntoBody)
    Given a Go struct <struct_type_description> defined with fields: <fields_with_tags_json>
    And an instance "DataInstance" of this struct populated with: <instance_data_json>
    And an empty `hclwrite.File` "f"
    When `gohcl.EncodeIntoBody` is called with "DataInstance" and `f.Body()`
    Then the HCL content of `f.Bytes()` should be:
      """
      <expected_hcl_string>
      """

    Examples:
      | struct_type_description | fields_with_tags_json                                                                 | instance_data_json                                     | expected_hcl_string                                 |
      | AttrPtrs                | `{"OptAttr":"hcl:\"opt_attr\"", "NilAttr":"hcl:\"nil_attr\""}` # Both fields are *string | `{"OptAttr":"value", "NilAttr":null}`                  | `opt_attr = "value"\n`                              | # Nil pointer attribute omitted
      | BlockPtrs               | `{"OptBlock":"hcl:\"opt_block,block\"", "NilBlock":"hcl:\"nil_block,block\""}` # Ptr to struct | `{"OptBlock":{}, "NilBlock":null}`                      | `\nopt_block {\n}\n`                                | # Nil pointer block omitted
      | IgnoredTags             | `{"Val":"hcl:\"val\"", "Rem":"hcl:\",remain\"", "Expr":"hcl:\"expr_field\""}` # Rem hcl.Body, Expr hcl.Expression | `{"Val":"v", "Rem": "some_body_data", "Expr":"expr_data"}` | `val = "v"\n`                                       | # ,remain and hcl.Expression fields ignored
      | Ordering                | `{"B":"hcl:\"b,block\"", "A":"hcl:\"a\""}`                                             | `{"B":{},"A":"val"}`                                   | `a = "val"\n\n_b {\n}\n`                            | # Attributes before blocks based on field order (simulated _ for block type for newline)

    # Notes for tables:
    # - JSON representations are used for complex struct data for clarity in Gherkin.
    # - `(struct_with_all_range_tags)` etc. are placeholders for complex Go struct definitions.
    # - `AttributeExpr` means a non-nil `*hcl.Attribute`. `BodyWithAttrAge` implies an `hcl.Body` that would yield that attribute.
    # - `null` in instance_data_json means the Go pointer is nil.
    # - The "Ordering" example simulates a block type change to ensure a newline is inserted; actual block type is "b".
    # - Output HCL string formatting (indentation, newlines) is as produced by hclwrite.
