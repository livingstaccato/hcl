# Covers tests in ./hclwrite/ast_block_test.go
# Specifically, TestBlockType, TestBlockLabels, TestBlockSetType, and TestBlockSetLabels

Feature: HCL Write AST - Block Manipulation
  This feature tests the manipulation of HCL block structures within the `hclwrite`
  Abstract Syntax Tree (AST). It covers retrieving block types and labels,
  and modifying a block's type and labels, then verifying the resulting token stream.

  Scenario Outline: Retrieving Block Type
    Given an HCL input string: <hcl_input>
    When the input is parsed into an `hclwrite.File`
    Then no parsing diagnostics should be reported
    And the type of the first block in the file body should be "<expected_type>"

    Examples:
      | hcl_input                         | expected_type |
      | `service {\n  attr0 = "val0"\n}` | "service"     |

  Scenario Outline: Retrieving Block Labels
    Given an HCL input string: <hcl_input>
    When the input is parsed into an `hclwrite.File`
    Then no parsing diagnostics should be reported
    And the labels of the first block in the file body should be <expected_labels_list>

    Examples:
      | hcl_input                                  | expected_labels_list        |
      | `nolabel {}`                               | []                          |
      | `quoted "label1" {}`                       | ["label1"]                  |
      | `quoted "label1" "label2" {}`              | ["label1", "label2"]        |
      | `quoted "label1" /* foo */ "label2" {}`    | ["label1", "label2"]        | # Comments between labels
      | `unquoted label1 {}`                       | ["label1"]                  |
      | `unquoted label1 /* foo */ label2 {}`       | ["label1", "label2"]        |
      | `mixed label1 "label2" {}`                 | ["label1", "label2"]        |
      | `escape "\\u0041" {}`                      | ["A"]                       | # Unicode escape for "A"
      | `blank "" {}`                              | [""]                        | # Blank label

  Scenario Outline: Setting Block Type and Verifying Tokens
    Given an HCL input string: "<initial_hcl>"
    And the first block has type "<old_type_name>" and labels <initial_labels_list_if_any>
    When the input is parsed into an `hclwrite.File`
    Then no parsing diagnostics should be reported
    When the type of this block is set to "<new_type_name>"
    And the file's tokens are built and formatted
    Then the resulting token stream should match: <expected_token_stream>

    Examples:
      | initial_hcl | old_type_name | initial_labels_list_if_any | new_type_name | expected_token_stream                                                                                                |
      | `foo {}`    | "foo"         | []                         | "bar"         | Ident(bar) OBrace CBrace EOF                                                                                         |

  Scenario Outline: Setting Block Labels and Verifying Tokens
    Given an HCL input string: "<initial_hcl>"
    And the first block has type "<type_name>" and labels <old_labels_list>
    When the input is parsed into an `hclwrite.File`
    Then no parsing diagnostics should be reported
    When the labels of this block are set to <new_labels_list>
    And the file's tokens are built and formatted
    Then the resulting token stream should match: <expected_token_stream>

    Examples:
      | initial_hcl                     | type_name | old_labels_list    | new_labels_list | expected_token_stream                                                                                                |
      | `foo "hoge" {}`                 | "foo"     | ["hoge"]           | ["fuga"]        | Ident(foo) OQuote QuotedLit(fuga) CQuote OBrace CBrace EOF                                                           | # Update first label
      | `foo "hoge" "fuga" {}`          | "foo"     | ["hoge", "fuga"]   | ["hoge", "piyo"]| Ident(foo) OQuote QuotedLit(hoge) CQuote OQuote QuotedLit(piyo) CQuote OBrace CBrace EOF                               | # Update second label
      | `foo {}`                        | "foo"     | []                 | ["fuga"]        | Ident(foo) OQuote QuotedLit(fuga) CQuote OBrace CBrace EOF                                                           | # Insert new label to empty list
      | `foo "hoge" {}`                 | "foo"     | ["hoge"]           | []              | Ident(foo) OBrace CBrace EOF                                                                                         | # Remove all labels
      | `foo "hoge" /* fuga */ "piyo" {}`| "foo"     | ["hoge", "piyo"]   | ["fuga"]        | Ident(foo) OQuote QuotedLit(fuga) CQuote OBrace CBrace EOF                                                           | # Reduce labels, ensure quoted
      | `foo "hoge" /* foo */  "" {}`   | "foo"     | ["hoge", ""]       | ["fuga"]        | Ident(foo) OQuote QuotedLit(fuga) CQuote OBrace CBrace EOF                                                           | # Reduce labels, handles empty string label

    # Notes for token stream representation:
    # - Token types are shorthands: Ident, OBrace, CBrace, OQuote, CQuote, QuotedLit, EOF.
    # - Bytes for tokens are implied (e.g., Ident(bar) means hclsyntax.TokenIdent with Bytes: []byte(`bar`)).
    # - SpacesBefore are handled by the `format()` call in the Go test and are implicitly expected between tokens where appropriate.
    # - `initial_labels_list_if_any` is used to locate the block for `SetType`. For `SetLabels`, `old_labels_list` is used.
