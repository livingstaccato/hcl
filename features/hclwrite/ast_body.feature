# This BDD feature file corresponds to the Go test file:
# ./hclwrite/ast_body_test.go
#
# It covers methods for inspecting and manipulating attributes and blocks
# within an hclwrite.Body AST node.

Feature: HCL Write AST - Body Operations
  This feature tests operations on an `hclwrite.Body` object, such as getting,
  setting, renaming, and removing attributes and blocks. It ensures that these
  manipulations correctly update the underlying token stream and preserve formatting
  where appropriate.

  Background:
    Given a HCL writing context

  Scenario Outline: Getting an Attribute from a Body
    Given an HCL input string parsed into an `hclwrite.File`:
      """
      <hcl_input>
      """
    When `GetAttribute("<attribute_name>")` is called on the file's body
    Then the tokens of the retrieved attribute should be <expected_attribute_tokens_json_or_null>
      # expected_attribute_tokens_json_or_null: JSON of token list, or "null" if not found.

    Examples:
      | hcl_input                 | attribute_name | expected_attribute_tokens_json_or_null |
      | `a = 1\n`                 | "a"            | `[{"type":"TokenIdent","bytes":"a"}, {"type":"TokenEqual","bytes":"=","spaces":1}, {"type":"TokenNumberLit","bytes":"1","spaces":1}, {"type":"TokenNewline","bytes":"\\n"}]` |
      | `a = 1\n`                 | "b"            | `null`                                 |
      | `a = 1\n#c\nb = 2\n`      | "b"            | `[{"type":"TokenComment","bytes":"#c\\n"}, {"type":"TokenIdent","bytes":"b"}, {"type":"TokenEqual","bytes":"=","spaces":1}, {"type":"TokenNumberLit","bytes":"2","spaces":1}, {"type":"TokenNewline","bytes":"\\n"}]` |

  Scenario Outline: Finding the First Matching Block in a Body
    Given an HCL input string parsed into an `hclwrite.File`:
      """
      <hcl_input>
      """
    When `FirstMatchingBlock("<block_type>", <labels_list_str>)` is called on the file's body
    Then the string representation of the found block's tokens should be "<expected_block_string_or_empty>"
      # expected_block_string_or_empty: The HCL string of the block, or "" if not found.

    Examples:
      | hcl_input                                     | block_type | labels_list_str    | expected_block_string_or_empty      |
      | `svc {}\nsvc "l1" {}\n`                       | "svc"      | `[]`               | `svc {\n}\n`                        |
      | `svc {}\nsvc "l1" {}\n`                       | "svc"      | `["l1"]`           | `svc "l1" {\n}\n`                   |
      | `svc "l1" "l2" {}\n`                          | "svc"      | `["l1", "l2"]`     | `svc "l1" "l2" {\n}\n`              |
      | `svc {}\n`                                    | "other"    | `[]`               | `""`                                |
      | `parent {\n child {}\n}\n`                    | "parent"   | `[]`               | `parent {\n  child {\n  }\n}\n`     |
      | `parent {\n child {}\n}\n`                    | "child"    | `[]`               | `""`                                | # FirstMatchingBlock is not recursive for this test

  Scenario Outline: Setting Attribute Value in a Body
    Given an initial HCL input string: "<initial_hcl>"
    When the input is parsed into an `hclwrite.File` "F"
    And `F.Body().SetAttributeValue("<attribute_name>", <cty_value_repr>)` is called
    Then the formatted HCL string of "F" should be:
      """
      <expected_hcl_output>
      """

    Examples:
      | initial_hcl | attribute_name | cty_value_repr | expected_hcl_output |
      | ``          | "a"            | `cty.True`     | `a = true\n`        |
      | `b = false\n`| "a"           | `cty.True`     | `b = false\na = true\n` |
      | `a = false\n`| "a"           | `cty.True`     | `a = true\n`        | # Overwrite
      | `a = 1\nb = false\n`| "a"    | `cty.True`     | `a = true\nb = false\n` |

  Scenario Outline: Setting Attribute Traversal in a Body
    Given an initial HCL input string: "<initial_hcl>"
    And a traversal parsed from "<traversal_hcl_string>" as "Trav"
    When the input is parsed into an `hclwrite.File` "F"
    And `F.Body().SetAttributeTraversal("<attribute_name>", Trav)` is called
    Then the formatted HCL string of "F" should be:
      """
      <expected_hcl_output>
      """

    Examples:
      | initial_hcl | attribute_name | traversal_hcl_string | expected_hcl_output |
      | ``          | "a"            | `b`                  | `a = b\n`           |
      | ``          | "a"            | `b.c.d`              | `a = b.c.d\n`       |
      | ``          | "a"            | `b[0]`               | `a = b[0]\n`        |
      | ``          | "a"            | `b[0].c`             | `a = b[0].c\n`      |

  Scenario Outline: Setting Attribute with Raw Tokens in a Body
    Given an initial HCL input string: "<initial_hcl>"
    And a `hclwrite.Tokens` sequence "RawTokens" representing `true` (TokenIdent "true")
    When the input is parsed into an `hclwrite.File` "F"
    And `F.Body().SetAttributeRaw("<attribute_name>", RawTokens)` is called
    Then the formatted HCL string of "F" should be:
      """
      <expected_hcl_output>
      """

    Examples:
      | initial_hcl | attribute_name | expected_hcl_output     |
      | ``          | "a"            | `a = true\n`            |
      | `a = 23\n`  | "a"            | `a = true\n`            | # Overwrite
      | `b = 23\n`  | "a"            | `b = 23\na = true\n`    |

  Scenario: Setting Attribute Value within a Block's Body
    Given an HCL input `service "label1" {\n  attr1 = "val1"\n}\n` parsed into "F"
    When block "SvcBlock" is retrieved using `F.Body().FirstMatchingBlock("service", ["label1"])`
    And `SvcBlock.Body().SetAttributeValue("attr1", cty.StringVal("updated1"))` is called
    Then the formatted HCL string of "F" should be `service "label1" {\n  attr1 = "updated1"\n}\n`

  Scenario: Setting Attribute Value within a Nested Block's Body
    Given an HCL input `parent {\n  attrP = "valP"\n  child {\n    attrC = "valC"\n  }\n}\n` parsed into "F"
    When block "ParentBlock" is retrieved using `F.Body().FirstMatchingBlock("parent", [])`
    And block "ChildBlock" is retrieved using `ParentBlock.Body().FirstMatchingBlock("child", [])`
    And `ChildBlock.Body().SetAttributeValue("attrC", cty.StringVal("updatedC"))` is called
    Then the formatted HCL string of "F" should be `parent {\n  attrP = "valP"\n  child {\n    attrC = "updatedC"\n  }\n}\n`

  Scenario Outline: Removing an Attribute from a Body
    Given an initial HCL input string: "<initial_hcl>"
    When the input is parsed into an `hclwrite.File` "F"
    And `F.Body().RemoveAttribute("<attribute_name>")` is called
    Then the formatted HCL string of "F" should be:
      """
      <expected_hcl_output>
      """

    Examples:
      | initial_hcl       | attribute_name | expected_hcl_output |
      | ``                | "a"            | ``                  | # No-op
      | `b = false\n`     | "a"            | `b = false\n`       | # No-op
      | `a = false\n`     | "a"            | ``                  |
      | `a = 1\nb = false\n`| "a"          | `b = false\n`       |

  Scenario Outline: Renaming an Attribute in a Body
    Given an initial HCL input string: "<initial_hcl>"
    When the input is parsed into an `hclwrite.File` "F"
    And `F.Body().RenameAttribute("<old_name>", "<new_name>")` is called, returning "success_status"
    Then the formatted HCL string of "F" should be:
      """
      <expected_hcl_output>
      """
    And "success_status" should be <expected_success_status>

    Examples:
      | initial_hcl          | old_name | new_name | expected_hcl_output    | expected_success_status |
      | ``                   | "a"      | "b"      | ``                     | false                   |
      | `a = false\n`        | "a"      | "b"      | `b = false\n`          | true                    |
      | `a = false\n`        | "b"      | "c"      | `a = false\n`          | false                   |
      | `a = false\nb = true\n`| "a"      | "b"      | `a = false\nb = true\n`| false                   | # Conflict

  Scenario Outline: Appending a New Block to a Body
    Given an initial HCL input string: "<initial_hcl>"
    When the input is parsed into an `hclwrite.File` "F"
    And `F.Body().AppendNewBlock("<block_type>", <labels_list_str>)` is called
    Then the formatted HCL string of "F" should be:
      """
      <expected_hcl_output>
      """

    Examples:
      | initial_hcl | block_type | labels_list_str    | expected_hcl_output          |
      | ``          | "foo"      | `[]`               | `foo {\n}\n`                 |
      | ``          | "foo"      | `["bar"]`          | `foo "bar" {\n}\n`           |
      | ``          | "foo"      | `["bar", "baz"]`   | `foo "bar" "baz" {\n}\n`     |
      | `bar {}\n`  | "foo"      | `[]`               | `bar {\n}\n\nfoo {\n}\n`     | # Newline separation

  Scenario: Removing a Block from a Body
    Given an HCL input `a = 1\n\n# Foo\nfoo {\n  b = 1\n}\nfoo {\n  b = 2\n}\nbar {}\n` parsed into "F"
    When the first block of type "foo" (Block1) is retrieved from `F.Body()`
    And `F.Body().RemoveBlock(Block1)` is called, returning "removed1"
    Then "removed1" should be true
    And the formatted HCL string of "F" should be `a = 1\n\nfoo {\n  b = 2\n}\n\nbar {\n}\n`
    When the remaining block of type "foo" (Block2) is retrieved from `F.Body()`
    And `F.Body().RemoveBlock(Block2)` is called, returning "removed2"
    Then "removed2" should be true
    And the formatted HCL string of "F" should be `a = 1\n\nbar {\n}\n`

    # Notes:
    # - `expected_attribute_tokens_json_or_null`: For GetAttribute, represents the direct tokens of the attribute.
    # - `labels_list_str`: String representation of a string slice, e.g., `["label1", "label2"]` or `[]`.
    # - `cty_value_repr`: Simplified cty.Value string representation (e.g., `cty.True`, `cty.StringVal("text")`).
    # - Formatted HCL output examples imply canonical formatting (spaces, newlines).
    # - The `RemoveBlock` scenario implies specific ordering and comment handling based on the Go test.
```
