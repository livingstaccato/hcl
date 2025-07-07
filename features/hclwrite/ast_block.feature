# Covers hclwrite.Block methods in ./hclwrite/ast_block.go
# Based on test cases in ./hclwrite/ast_block_test.go

Feature: HCL Write AST - Block Manipulation
  This feature tests the creation, inspection, and modification of HCL block
  structures within the `hclwrite` Abstract Syntax Tree (AST). It ensures
  that operations like getting/setting types and labels correctly reflect
  in the underlying token stream.

  Scenario Outline: Retrieving Block Type using Block.Type()
    Given an HCL input string: <hcl_input>
    When the input is parsed into an `hclwrite.File`
    Then no parsing diagnostics should be reported
    And the `Type()` method of the first block in the file body should return "<expected_type>"

    Examples:
      | hcl_input                         | expected_type |
      | `service {\n  attr0 = "val0"\n}` | "service"     |
      | `resource "foo" "bar" {}`         | "resource"    |

  Scenario Outline: Retrieving Block Labels using Block.Labels()
    Given an HCL input string: <hcl_input>
    When the input is parsed into an `hclwrite.File`
    Then no parsing diagnostics should be reported
    And the `Labels()` method of the first block in the file body should return the list <expected_labels_list_str>

    Examples:
      | hcl_input                               | expected_labels_list_str |
      | `nolabel {}`                            | `[]`                       |
      | `quoted "label1" {}`                    | `["label1"]`               |
      | `quoted "label1" "label2" {}`           | `["label1", "label2"]`     |
      | `quoted "label1" /*c*/ "label2" {}`     | `["label1", "label2"]`     | # Comment between labels
      | `unquoted label1 {}`                    | `["label1"]`               |
      | `unquoted label1 /*c*/ label2 {}`        | `["label1", "label2"]`     |
      | `mixed label1 "label2" {}`              | `["label1", "label2"]`     |
      | `escape "\\u0041" {}`                   | `["A"]`                    | # Unicode escape for "A"
      | `blank "" {}`                           | `[""]`                     | # Blank label

  Scenario Outline: Setting Block Type using Block.SetType() and verifying tokens
    Given an HCL input string: "<initial_hcl>"
    And the first block has type "<old_type_name>" and labels <initial_labels_list>
    When the input is parsed into an `hclwrite.File`
    And no parsing diagnostics are reported
    And the type of this block is set to "<new_type_name>" using `SetType`
    And the file's tokens are built and then formatted
    Then the resulting token stream should be: <expected_token_stream_repr>

    Examples:
      | initial_hcl | old_type_name | initial_labels_list | new_type_name | expected_token_stream_repr           |
      | `foo {}`    | "foo"         | []                  | "bar"         | `Ident(bar) OBrace CBrace EOF`       |

  Scenario Outline: Setting Block Labels using Block.SetLabels() and verifying tokens
    Given an HCL input string: "<initial_hcl>"
    And the first block has type "<type_name>" and initial labels <old_labels_list_str>
    When the input is parsed into an `hclwrite.File`
    And no parsing diagnostics are reported
    And the labels of this block are set to <new_labels_list_str> using `SetLabels`
    And the file's tokens are built and then formatted
    Then the resulting token stream should be: <expected_token_stream_repr>

    Examples:
      | initial_hcl                     | type_name | old_labels_list_str | new_labels_list_str | expected_token_stream_repr                                                              |
      | `foo "hoge" {}`                 | "foo"     | `["hoge"]`          | `["fuga"]`        | `Ident(foo) OQuote QuotedLit(fuga) CQuote OBrace CBrace EOF`                            |
      | `foo "hoge" "fuga" {}`          | "foo"     | `["hoge","fuga"]`   | `["hoge","piyo"]` | `Ident(foo) OQuote QuotedLit(hoge) CQuote OQuote QuotedLit(piyo) CQuote OBrace CBrace EOF` |
      | `foo {}`                        | "foo"     | `[]`                | `["fuga"]`        | `Ident(foo) OQuote QuotedLit(fuga) CQuote OBrace CBrace EOF`                            |
      | `foo "hoge" {}`                 | "foo"     | `["hoge"]`          | `[]`              | `Ident(foo) OBrace CBrace EOF`                                                          |
      | `foo "hoge" /*c*/ "piyo" {}`    | "foo"     | `["hoge","piyo"]`   | `["fuga"]`        | `Ident(foo) OQuote QuotedLit(fuga) CQuote OBrace CBrace EOF`                            |

  Scenario: Accessing the Body of a Block
    Given an `hclwrite.Block` instance "MyBlock" (e.g., created with `NewBlock("my_type", [])`)
    When `MyBlock.Body()` is called
    Then a non-nil `*hclwrite.Body` object should be returned
    And this body object can be used to append attributes or nested blocks to "MyBlock"

    # Notes for tables:
    # - `expected_labels_list_str`: String representation of a string slice, e.g., `["label1", "label2"]`.
    # - `expected_token_stream_repr`: Simplified representation of hclwrite.Tokens.
    #   - Types: Ident, OBrace, CBrace, OQuote, CQuote, QuotedLit, EOF.
    #   - (value) indicates token Bytes, e.g., Ident(bar), QuotedLit(fuga).
    #   - Formatting (spaces, newlines) is applied by `format()` in Go tests and implied in expected stream.
    # - `initial_labels_list` in SetType scenario helps identify the target block if multiple exist.
