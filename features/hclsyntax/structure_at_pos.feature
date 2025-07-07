# Covers methods on hcl.File in ./structure_at_pos.go
# Based on test cases in ./hclsyntax/structure_at_pos_test.go, which test these
# methods using an hclsyntax.Body implementation.

Feature: HCL Syntax - Locating Structure Elements by Source Position
  This feature tests the ability to identify HCL structural elements like blocks,
  attributes, and expressions at a specific byte offset within a parsed HCL file
  (specifically when parsed using the HCL native syntax parser).

  Background:
    Given an HCL configuration string is parsed into an `hcl.File` object using `hclsyntax.ParseConfig`
    And parsing diagnostics are ignored for the purpose of testing structural queries on potentially recovered ASTs

  Scenario Outline: Finding containing blocks at a given source position
    Given the HCL input string:
      """
      <hcl_input>
      """
    And a target byte offset <byte_offset> (1-based for Gherkin, converted to 0-based for Go Pos)
    When `File.BlocksAtPos(Pos(byte_offset))` is called
    Then the list of returned block types should be <expected_block_types_list_as_string>
    When `File.OutermostBlockAtPos(Pos(byte_offset))` is called
    Then the returned block's type should be "<outermost_type_or_empty>" or nil if empty
    When `File.InnermostBlockAtPos(Pos(byte_offset))` is called
    Then the returned block's type should be "<innermost_type_or_empty>" or nil if empty

    Examples:
      | hcl_input                                       | byte_offset | expected_block_types_list_as_string | outermost_type_or_empty | innermost_type_or_empty |
      | `""`                                            | 1           | "[]"                                | ""                      | ""                      | # Empty
      | `foo {}`                                        | 2           | `["foo"]`                           | "foo"                   | "foo"                   | # In header
      | `foo {    }`                                    | 8           | `["foo"]`                           | "foo"                   | "foo"                   | # In body
      | `\nfoo {\n\n  bar {\n\n  }\n}\n`                 | 11          | `["foo"]`                           | "foo"                   | "foo"                   | # In outer body, nested unselected
      | `\nfoo {\n  bar {\n\n  }\n}\n`                 | 21          | `["foo", "bar"]`                    | "foo"                   | "bar"                   | # In inner body
      | `\nfoo {\n  bar{\n    baz{\n\n    }\n  }\n  nw{}\n}\n` | 32    | `["foo", "bar", "baz"]`             | "foo"                   | "baz"                   | # Nested three levels, sibling after
      | `foo {    `                                     | 8           | `["foo"]`                           | "foo"                   | "foo"                   | # Unterminated block

  Scenario Outline: Finding the attribute definition at a given source position
    Given the HCL input string:
      """
      <hcl_input>
      """
    And a target byte offset <byte_offset> (1-based for Gherkin)
    When `File.AttributeAtPos(Pos(byte_offset))` is called
    Then the name of the returned hcl.Attribute should be "<expected_attribute_name_or_empty>" or nil if empty

    Examples:
      | hcl_input                     | byte_offset | expected_attribute_name_or_empty |
      | `""`                          | 1           | ""                               |
      | `foo = 1`                     | 1           | "foo"                            | # On name
      | `foo = 1`                     | 5           | "foo"                            | # On value
      | `\nfoo = 1\nbar = 2\n`        | 7           | "foo"                            |
      | `\nfoo = 1\nbar = 2\n`        | 18          | "bar"                            |
      | `\nfoo {\n  bar = 2\n}\n`     | 18          | "bar"                            | # Nested attribute
      | `\nfoo {\n  bar = 2`          | 18          | "bar"                            | # Nested in unterminated

  Scenario Outline: Finding the outermost expression at a given source position
    Given the HCL input string: "<hcl_input>"
    And a target byte offset <byte_offset> (1-based for Gherkin)
    When `File.OutermostExprAtPos(Pos(byte_offset))` is called
    Then the source string of the returned hcl.Expression (sliced from original input) should be "<expected_expr_source_or_empty>" or empty if nil

    Examples:
      | hcl_input       | byte_offset | expected_expr_source_or_empty |
      | `""`            | 1           | ""                            |
      | `a = true`      | 7           | `true`                        | # On value "true"
      | `a = blah`      | 7           | `blah`                        |
      | `a = blah.foo`  | 7           | `blah.foo`                    |
      | `a = (1 + 1)`   | 7           | `(1 + 1)`                     | # On '('
      | `a = (1 + 1)`   | 9           | `(1 + 1)`                     | # On '1' inside parens
      | `a = [1, 2, 3]` | 6           | `[1, 2, 3]`                   | # On '['
      | `a = [1, 2, 3]` | 8           | `[1, 2, 3]`                   | # On '1' inside list
      | `a = foom("a")` | 11          | `foom("a")`                   | # On "a" inside func call

    # Notes for tables:
    # - Byte offsets in examples are 1-based for Gherkin table readability and converted to 0-based for hcl.Pos.
    # - `expected_block_types_list_as_string`: A string representation of a list of strings, e.g., `["foo", "bar"]`.
    # - `Pos(byte_offset)` refers to creating an hcl.Pos with the given byte offset (0-based), and Line/Column derived if needed for test setup.
    # - "or nil if empty" for block/attribute names means if the Gherkin value is "", the Go test expects nil.
    # - Slicing expression source is done using the expression's Range() and the original input bytes.
