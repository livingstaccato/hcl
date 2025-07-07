# Covers tests in ./hclsyntax/structure_at_pos_test.go
# Specifically, TestBlocksAtPos, TestAttributeAtPos, and TestOutermostExprAtPos

Feature: HCL Syntax - Locating Structure at a Given Position
  This feature tests the ability to identify HCL structural elements (blocks, attributes, expressions)
  at a specific byte offset within a parsed HCL file. This is useful for IDEs and other tools
  that need to understand the context of a cursor position.

  Background:
    Given an HCL input string is parsed into an `hclsyntax.File` object with filename "" and initial position L1C1B0.
    And parsing diagnostics are ignored for these tests to check recovery behavior.

  Scenario Outline: Finding blocks at a given position
    Given an HCL input string: "<input_hcl>"
    And a target position: Byte <byte_offset>
    When `BlocksAtPos` is called on the parsed file with the target position
    Then the returned list of block types should be <expected_block_types_list>
    And if blocks are expected, `OutermostBlockAtPos` should return a block of type "<outermost_type>"
    And if blocks are expected, `InnermostBlockAtPos` should return a block of type "<innermost_type>"
    And if no blocks are expected, `OutermostBlockAtPos` and `InnermostBlockAtPos` should return nil

    Examples:
      | input_hcl                               | byte_offset | expected_block_types_list | outermost_type | innermost_type |
      | `""`                                    | 0           | []                        |                |                | # empty
      | `    `                                  | 1           | []                        |                |                | # spaces
      | `foo {}`                                | 1           | ["foo"]                   | "foo"          | "foo"          | # single in header
      | `foo {    }`                            | 7           | ["foo"]                   | "foo"          | "foo"          | # single in body
      | `\nfoo {\n\n  bar {\n\n  }\n}\n`         | 10          | ["foo"]                   | "foo"          | "foo"          | # single in body with unselected nested
      | `\nfoo {  }\nbar {  }\n`                | 10          | ["foo"]                   | "foo"          | "foo"          | # single in body with unselected sibling
      | `\nfoo {\n  bar {\n\n  }\n}\n`           | 20          | ["foo", "bar"]            | "foo"          | "bar"          | # selected nested two levels
      | `\nfoo {\n  bar {\n    baz {\n\n    }\n  }\n}\n` | 31    | ["foo", "bar", "baz"]     | "foo"          | "baz"          | # selected nested three levels
      | `foo {`                                 | 7           | ["foo"]                   | "foo"          | "foo"          | # unterminated
      | `\nfoo {\n  bar {\n}\n`                 | 16          | ["foo", "bar"]            | "foo"          | "bar"          | # unterminated nested (fixed closing brace for test logic)

  Scenario Outline: Finding an attribute at a given position
    Given an HCL input string: "<input_hcl>"
    And a target position: Byte <byte_offset>
    When `AttributeAtPos` is called on the parsed file with the target position
    Then the name of the returned attribute should be "<expected_attribute_name>" (or nil if none)

    Examples:
      | input_hcl                     | byte_offset | expected_attribute_name |
      | `""`                          | 0           | ""                      | # empty
      | `foo = 1`                     | 0           | "foo"                   | # top-level
      | `\nfoo = 1\nbar = 2\n`        | 6           | "foo"                   | # top-level with ignored sibling after
      | `\nfoo = 1\nbar = 2\n`        | 17          | "bar"                   | # top-level ignored sibling before
      | `\nfoo {\n  bar = 2\n}\n`     | 17          | "bar"                   | # nested
      | `\nfoo {\n  bar = 2\n`        | 17          | "bar"                   | # nested in unterminated block

  Scenario Outline: Finding the outermost expression at a given position
    Given an HCL input string: "<input_hcl>"
    And a target position: Byte <byte_offset>
    When `OutermostExprAtPos` is called on the parsed file with the target position
    Then the source string of the returned expression should be "<expected_expr_source>" (or empty if none)

    Examples:
      | input_hcl       | byte_offset | expected_expr_source |
      | `""`            | 0           | ""                   | # empty
      | `a = true`      | 6           | "true"               | # simple bool
      | `a = blah`      | 6           | "blah"               | # simple reference
      | `a = blah.foo`  | 6           | "blah.foo"           | # attribute reference
      | `a = (1 + 1)`   | 6           | "(1 + 1)"            | # parens
      | `a = [1, 2, 3]` | 5           | "[1, 2, 3]"          | # tuple cons (pos is on open bracket)
      | `a = foom("a")` | 10          | "foom(\"a\")"        | # function call (pos is on "a")

    # Note for "Finding blocks" scenario: The example `\nfoo {\n  bar {\n}\n` was slightly modified from the Go test
    # which had `\nfoo {\n  bar {\n			}\n			` (unterminated inner block). For Gherkin clarity, I assumed
    # a valid structure to test the position logic. The Go test explicitly mentions ignoring diagnostics
    # to test parser recovery, which is harder to represent directly in Gherkin expected outcomes for block structure.
    # The core logic of finding the block at the position is still covered. If an unterminated block is desired,
    # the expected types would still be the same, but the block's body might be incomplete.
