# Covers tests in ./hclwrite/parser_test.go
# Specifically, TestParse, TestPartitionTokens, TestPartitionLeadCommentTokens, and TestLexConfig.
# The `makeTestTree` helper and `TestTreeNode` struct are used by TestParse.

Feature: HCL Write - Parsing and Tokenization Internals
  This feature tests the internal parsing logic of the `hclwrite` package,
  focusing on how HCL source code is transformed into an AST (Abstract Syntax Tree)
  represented by `hclwrite.node` and how raw tokens are processed by internal
  utility functions like `partitionTokens`, `partitionLeadCommentTokens`, and `lexConfig`.

  Scenario Outline: Parsing HCL configurations into an hclwrite AST
    Given an HCL input string:
      """
      <input_hcl>
      """
    When the input is parsed using `hclwrite.parse` (internal)
    Then no parsing diagnostics should be reported
    And the resulting AST, when converted to a `TestTreeNode` structure, should match:
      <expected_test_tree_structure>

    Examples:
      | input_hcl                  | expected_test_tree_structure                                                                                                                                                                                             |
      | `""`                       | Type:Body                                                                                                                                                                                                                |
      | `"a = 1\\n"`               | Type:Body Children:[ {Type:Attribute Children:[ {Type:comments}, {Type:identifier Val:a}, {Type:Tokens Val:" ="}, {Type:Expression Children:[{Type:Tokens Val:" 1"}]}, {Type:comments}, {Type:Tokens Val:"\\n"} ]} ] |
      | `"# c\\na = 1\\n"`         | Type:Body Children:[ {Type:Attribute Children:[ {Type:comments Val:"# c\\n"}, {Type:identifier Val:a}, {Type:Tokens Val:" ="}, {Type:Expression Children:[{Type:Tokens Val:" 1"}]}, {Type:comments}, {Type:Tokens Val:"\\n"} ]} ] |
      | `"a = 1 # c\\n"`           | Type:Body Children:[ {Type:Attribute Children:[ {Type:comments}, {Type:identifier Val:a}, {Type:Tokens Val:" ="}, {Type:Expression Children:[{Type:Tokens Val:" 1"}]}, {Type:comments Val:" # c\\n"} ]} ]           |
      | `"b {}\\n"`                | Type:Body Children:[ {Type:Block Children:[ {Type:comments}, {Type:identifier Val:b}, {Type:blockLabels}, {Type:Tokens Val:" {"}, {Type:Body}, {Type:Tokens Val:"}"}, {Type:Tokens Val:"\\n"} ]} ]                     |
      | `"b \\"l\\" {}\\n"`        | Type:Body Children:[ {Type:Block Children:[ {Type:comments}, {Type:identifier Val:b}, {Type:blockLabels Children:[{Type:quoted Val:" \\"l\\""}]}, {Type:Tokens Val:" {"}, {Type:Body}, {Type:Tokens Val:"}"}, {Type:Tokens Val:"\\n"} ]} ] |
      | `"a = foo.bar\\n"`         | Type:Body Children:[ {Type:Attribute Children:[ {T:comments}, {T:identifier V:a}, {T:Tokens V:" ="}, {T:Expression Children:[{T:Traversal Children:[{T:TraverseName Children:[{T:identifier V:" foo"}]},{T:TraverseName Children:[{T:Tokens V:"."},{T:identifier V:"bar"}]}]}]}, {T:comments}, {T:Tokens V:"\\n"} ]} ] |
      | `"a = foo[0]\\n"`         | Type:Body Children:[ {Type:Attribute Children:[ {T:comments}, {T:identifier V:a}, {T:Tokens V:" ="}, {T:Expression Children:[{T:Traversal Children:[{T:TraverseName Children:[{T:identifier V:" foo"}]},{T:TraverseIndex Children:[{T:Tokens V:"["},{T:number V:"0"},{T:Tokens V:"]"}]}]}]}, {T:comments}, {T:Tokens V:"\\n"} ]} ] |
      | `"a = foo.*\\n"`          | Type:Body Children:[ {Type:Attribute Children:[ {T:comments}, {T:identifier V:a}, {T:Tokens V:" ="}, {T:Expression Children:[{T:Traversal Children:[{T:TraverseName Children:[{T:identifier V:" foo"}]}]}, {T:Tokens V:".*"}] }, {T:comments}, {T:Tokens V:"\\n"} ]} ] |

  Scenario Outline: Partitioning a token slice by a given source range
    Given a sequence of HCL tokens: <hclsyntax_tokens_list>
    And a source range: StartByte <start_byte>, EndByte <end_byte>
    When `partitionTokens` is called with the tokens and range
    Then the returned start index should be <expected_start_index>
    And the returned end index should be <expected_end_index>

    Examples:
      | hclsyntax_tokens_list                                     | start_byte | end_byte | expected_start_index | expected_end_index |
      | `[]`                                                      | 0          | 0        | 0                    | 0                  |
      | `[Ident(B0-4)]`                                           | 0          | 4        | 0                    | 1                  |
      | `[Ident(B0-4), Ident(B4-8), Ident(B8-12)]`                | 4          | 8        | 1                    | 2                  |
      | `[Ident(B0-4), Ident(B4-8), Ident(B8-12)]`                | 0          | 8        | 0                    | 2                  |

  Scenario Outline: Partitioning leading comment tokens from a token slice
    Given a sequence of HCL tokens: <hclsyntax_tokens_list>
    When `partitionLeadCommentTokens` is called with the tokens
    Then the returned start index (of non-comment tokens) should be <expected_start_index>

    Examples:
      | hclsyntax_tokens_list                 | expected_start_index |
      | `[]`                                  | 0                    |
      | `[Comment]`                           | 0                    | # All comments, start remains 0 as per original logic if no non-comment found
      | `[Comment, Comment]`                  | 0                    | # All comments
      | `[Comment, Newline]`                  | 2                    | # Newline stops leading comments
      | `[Comment, Newline, Comment]`         | 2                    | # Newline stops, next comment not leading
      | `[Ident, Comment]`                    | 0                    | # Non-comment first

  Scenario Outline: Lexing HCL configuration string into hclwrite Tokens
    Given an HCL input string: "<input_hcl>"
    When `lexConfig` (internal) is called with the input
    Then the resulting `hclwrite.Tokens` should be: <expected_hclwrite_tokens_list>

    Examples:
      | input_hcl                      | expected_hclwrite_tokens_list                                                                                                                                    |
      | `"a  b "`                       | `[Ident(a SB:0), Ident(b SB:2), EOF(SB:1)]`                                                                                                                      |
      | `"\nfoo \\"bar\\" \\"baz\\" {\n    pizza = \\" cheese \\"\n}\n"` | `[NL(SB:0), Id(foo SB:0), OQ(SB:1), QL(bar SB:0), CQ(SB:0), OQ(SB:1), QL(baz SB:0), CQ(SB:0), OB(SB:1), NL(SB:0), Id(pizza SB:4), Eq(SB:1), OQ(SB:1), QL( cheese  SB:0), CQ(SB:0), NL(SB:0), CB(SB:0), NL(SB:0), EOF(SB:0)]` |

    # Notes for tables:
    # - TestTreeNode structure: Type:TypeName [Val:Value] [Children:[{sub-nodes}]]. T=Type, V=Val.
    # - Token representations for partitionTokens/lexConfig: Ident(bytes SB:spaces_before), NL, Comment, etc. B0-4 means Byte 0 to 4.
    # - For `lexConfig`, SB means SpacesBefore. OQ=OQuote, CQ=CQuote, QL=QuotedLit, OB=OBrace, CB=CBrace, Eq=Equal.
    # - Input HCL strings are Go-escaped for newlines, quotes.
    # - The `makeTestTree` function in the Go code has specific logic for determining `Val` (from `testValue()` or token bytes)
    #   and `Type` (from Go type name), which is reflected in the `expected_test_tree_structure`.
    # - The `partitionLeadCommentTokens` examples for all comments result in 0 based on how the loop would exit without finding a non-comment,
    #   but the function is designed to return the *start* of non-comment tokens. If all are comments, the behavior for start index might be len(tokens) or 0 depending on use-case.
    #   The Go test implies it returns the index *after* the leading comments and their terminating newline if present. If only comments, it seems to return 0.
    #   Adjusted Gherkin to reflect the Go test's specific behavior for all-comment/comment-newline cases.
    #   For `[Comment, Newline]`, `partitionLeadCommentTokens` returns 2, meaning non-comments start *after* the newline.
    #   For `[Comment]`, it returns 0, because there's no non-comment token to point *after* the comment sequence.
    #   The Gherkin `expected_start_index` for all-comment cases is adjusted to match the test's logic more closely. If only comments exist, it means non-comments start at index 0 (effectively none).
    #   The actual Go test for `[Comment]` and `[Comment, Comment]` would result in `wantStart = 0`.
    #   If `[Comment, Newline]`, then `wantStart = 2`. Let's ensure Gherkin matches this.
    #   Corrected `partitionLeadCommentTokens` examples based on Go test logic: If it's all comments, or comments then EOF, it effectively means no non-comment part, so index 0 is fine. If a newline follows comments, non-comments start after that newline.
