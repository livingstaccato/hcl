# This BDD feature file corresponds to the Go test file:
# ./hclsyntax/structure_test.go
#
# It covers the behavior of hclsyntax.Body's Content, PartialContent,
# and JustAttributes methods when processing HCL structures against a schema.

Feature: HCL Syntax Structure Processing
  This feature describes how an HCL body's content (attributes and blocks)
  is processed and validated against a given HCL schema, resulting in
  a structured representation or diagnostics.

  Background:
    Given an HCL syntax context

  Scenario Outline: Processing Body Attributes against a Schema
    Given an `hclsyntax.Body` with attributes: <body_attributes_json>
    And an `hcl.BodySchema` with attribute schemas: <attribute_schemas_json>
    And the processing mode is "<mode>" (full or partial)
    When the body's content is retrieved using the schema
    Then the resulting `hcl.BodyContent.Attributes` should match: <expected_content_attributes_json>
    And the number of diagnostics should be <expected_diag_count>
    And if diagnostics are expected, the first relevant diagnostic summary should contain "<expected_error_summary_contains>"

    Examples:
      | body_attributes_json | attribute_schemas_json               | mode    | expected_content_attributes_json | expected_diag_count | expected_error_summary_contains   |
      | `{}`                 | `[]`                                 | full    | `{}`                             | 0                   |                                   |
      | `{"foo":{}}`         | `[{"Name":"foo"}]`                   | full    | `{"foo":{}}`                     | 0                   |                                   |
      | `{"foo":{}}`         | `[]`                                 | full    | `{}`                             | 1                   | "Unsupported attribute"           | # foo not expected
      | `{"foo":{}}`         | `[]`                                 | partial | `{}`                             | 0                   |                                   | # foo ignored in partial
      | `{}`                 | `[{"Name":"foo"}]`                   | full    | `{}`                             | 0                   |                                   | # foo optional
      | `{}`                 | `[{"Name":"foo", "Required":true}]`  | full    | `{}`                             | 1                   | "Missing required attribute"      | # foo required
      | `{"foo":{}}`         | `[{"BlockType":"foo"}]`              | full    | `{}`                             | 1                   | "Attribute "foo" is not expected" | # Attr/Block name collision

  Scenario Outline: Processing Body Blocks against a Schema
    Given an `hclsyntax.Body` with blocks: <body_blocks_json>
      # body_blocks_json is like: `[{"Type":"foo", "Labels":["l1"]}, ...]`
    And an `hcl.BodySchema` with block header schemas: <block_schemas_json>
      # block_schemas_json is like: `[{"Type":"foo", "LabelNames":["name"]}, ...]`
    And the processing mode is "<mode>" (full or partial)
    When the body's content is retrieved using the schema
    Then the resulting `hcl.BodyContent.Blocks` should match: <expected_content_blocks_json>
    And the number of diagnostics should be <expected_diag_count>
    And if diagnostics are expected, the first relevant diagnostic summary should contain "<expected_error_summary_contains>"

    Examples:
      | body_blocks_json             | block_schemas_json                      | mode    | expected_content_blocks_json   | expected_diag_count | expected_error_summary_contains |
      | `[{"Type":"foo"}]`           | `[{"Type":"foo"}]`                      | full    | `[{"Type":"foo"}]`             | 0                   |                                 |
      | `[{"Type":"foo"},{"Type":"foo"}]` | `[{"Type":"foo"}]`                  | full    | `[{"Type":"foo"},{"Type":"foo"}]`| 0                   |                                 |
      | `[{"Type":"foo"},{"Type":"bar"}]` | `[{"Type":"foo"}]`                  | full    | `[{"Type":"foo"}]`             | 1                   | "Unsupported block type"        | # bar not expected
      | `[{"Type":"foo"},{"Type":"bar"}]` | `[{"Type":"foo"}]`                  | partial | `[{"Type":"foo"}]`             | 0                   |                                 | # bar ignored in partial
      | `[{"Type":"foo", "Labels":["l1"]}]` | `[{"Type":"foo", "LabelNames":["n"]}]` | full | `[{"Type":"foo", "Labels":["l1"]}]`| 0                 |                                 |
      | `[{"Type":"foo"}]`           | `[{"Type":"foo", "LabelNames":["n"]}]` | full    | `[]`                           | 1                   | "MissingS Labels"             | # Expected labels
      | `[{"Type":"foo", "Labels":["l1"]}]` | `[{"Type":"foo"}]`                | full    | `[]`                           | 1                   | "Extraneous Labels"           | # Unexpected labels
      | `[{"Type":"foo", "Labels":["l1","l2"]}]` | `[{"Type":"foo", "LabelNames":["n"]}]` | full | `[]`                       | 1                   | "Too many labels"               |

  Scenario Outline: Retrieving Only Attributes using JustAttributes
    Given an `hclsyntax.Body` with attributes: <body_attributes_json> and blocks: <body_blocks_json>
    And the body has hidden attributes: <hidden_attributes_list_json> # e.g., ["hidden_attr"]
    When `body.JustAttributes()` is called
    Then the resulting `hcl.Attributes` should match: <expected_attributes_json>
    And the number of diagnostics should be <expected_diag_count>
    And if diagnostics are expected, the first relevant diagnostic summary should contain "<expected_error_summary_contains>"

    Examples:
      | body_attributes_json      | body_blocks_json   | hidden_attributes_list_json | expected_attributes_json | expected_diag_count | expected_error_summary_contains |
      | `{}`                      | `[]`               | `[]`                        | `{}`                     | 0                   |                                 |
      | `{"foo":{"Expr":"bar"}}`  | `[]`               | `[]`                        | `{"foo":{"Expr":"bar"}}` | 0                   |                                 |
      | `{"foo":{"Expr":"bar"}}`  | `[{"Type":"b"}]`   | `[]`                        | `{"foo":{"Expr":"bar"}}` | 1                   | "Blocks are not allowed here"   |
      | `{"foo":{},"hid":{}}`     | `[]`               | `["hid"]`                   | `{"foo":{}}`             | 0                   |                                 | # Hidden attr not returned

    # Notes for table values:
    # - JSON representations are simplified.
    # - For attributes: `{"name":{...hcl.Attribute fields...}}`. An empty `{}` implies presence.
    # - For blocks: `[{"Type":"type", "Labels":["l1","l2"], ...hcl.Block fields...}]`.
    # - `expected_content_attributes_json` and `expected_content_blocks_json` describe the hcl.Attributes and hcl.Blocks in the hcl.BodyContent.
    # - The "hidden_attributes_list_json" simulates attributes that might have been processed by a prior PartialContent call.
    # - The structure of hcl.Attribute and hcl.Block in the output is simplified to focus on key identifying features.
```
