# Covers tests in ./hclwrite/generate_test.go
# Specifically, TestTokensForValue, TestTokensForTraversal, TestTokensForTuple,
# TestTokensForObject, TestTokensForFunctionCall, and TestTokenGenerateConsistency.

Feature: HCL Write - Token Generation
  This feature tests the functions in `hclwrite` that generate HCL token sequences
  from various inputs like `cty.Value`, `hcl.Traversal`, and structured token arrays.
  It ensures that the generated tokens correctly represent the input in HCL syntax.

  Scenario Outline: Generating Tokens for cty.Value
    Given a cty.Value: <cty_value_string_representation>
    When `TokensForValue` is called with this cty.Value
    Then the resulting token stream should be: <expected_token_stream>

    Examples:
      | cty_value_string_representation        | expected_token_stream                                                                                                |
      | `cty.NullVal(cty.DynamicPseudoType)`   | Ident(null)                                                                                                          |
      | `cty.True`                             | Ident(true)                                                                                                          |
      | `cty.NumberIntVal(0)`                  | Num(0)                                                                                                               |
      | `cty.NumberFloatVal(0.5)`              | Num(0.5)                                                                                                             |
      | `cty.StringVal("")`                    | OQuote CQuote                                                                                                        |
      | `cty.StringVal("foo")`                 | OQuote QuotedLit(foo) CQuote                                                                                         |
      | `cty.StringVal("\\"foo\\"")`           | OQuote QuotedLit(\\"foo\\") CQuote                                                                                   | # Escaped quotes
      | `cty.StringVal("hello\\nworld\\n")`    | OQuote QuotedLit(hello\\nworld\\n) CQuote                                                                            | # Newlines in string
      | `cty.StringVal("𝄞")`                   | OQuote QuotedLit(𝄞) CQuote                                                                                           | # Unicode char
      | `cty.EmptyTupleVal`                    | OBrack CBrack                                                                                                        |
      | `cty.TupleVal([cty.True])`             | OBrack Ident(true) CBrack                                                                                            |
      | `cty.TupleVal([cty.True, Num(0)])`     | OBrack Ident(true) Comma Num(0 SpaceBefore:1) CBrack                                                                 |
      | `cty.EmptyObjectVal`                   | OBrace CBrace                                                                                                        |
      | `cty.ObjectVal({foo:cty.True})`        | OBrace NL Ident(foo SpaceBefore:2) Eq(SpaceBefore:1) Ident(true SpaceBefore:1) NL CBrace                             |
      | `cty.ObjectVal({"foo bar":cty.True})`  | OBrace NL OQuote(SpaceBefore:2) QuotedLit(foo bar) CQuote Eq(SB:1) Ident(true SB:1) NL CBrace                         | # Key with space

  Scenario Outline: Generating Tokens for hcl.Traversal
    Given an hcl.Traversal: <traversal_description>
    When `TokensForTraversal` is called with this traversal
    Then the resulting token stream should be: <expected_token_stream>

    Examples:
      | traversal_description                     | expected_token_stream                                                                   |
      | `root.attr["index"]` (TraverseRoot Name:"root", TraverseAttr Name:"attr", TraverseIndex Key:StringVal("index")) | Ident(root) Dot Ident(attr) OBrack OQuote QuotedLit(index) CQuote CBrack |

  Scenario Outline: Generating Tokens for a Tuple from element Tokens
    Given a list of Token sequences for tuple elements: <elements_token_lists_description>
    When `TokensForTuple` is called with this list
    Then the resulting token stream should be: <expected_token_stream>

    Examples:
      | elements_token_lists_description                | expected_token_stream                                                                         |
      | `[]` (empty list)                               | OBrack CBrack                                                                                 |
      | `[ TokensForValue(StringVal("foo")) ]`          | OBrack OQuote QuotedLit(foo) CQuote CBrack                                                    |
      | `[ TokensForTraversal(root.attr), TokensForValue(StringVal("foo")) ]` | OBrack Ident(root) Dot Ident(attr) Comma OQuote(SB:1) QuotedLit(foo) CQuote CBrack |

  Scenario Outline: Generating Tokens for an Object from attribute Tokens
    Given a list of ObjectAttrTokens: <object_attr_tokens_list_description>
    When `TokensForObject` is called with this list
    Then the resulting token stream should be: <expected_token_stream>

    Examples:
      | object_attr_tokens_list_description                                      | expected_token_stream                                                                                                  |
      | `[]` (empty list)                                                        | OBrace CBrace                                                                                                          |
      | `[{ Name:TokensForRoot("bar"), Value:TokensForValue(StringVal("baz")) }]` | OBrace NL Ident(bar SB:2) Eq(SB:1) OQuote(SB:1) QuotedLit(baz) CQuote NL CBrace                                         |
      | `[{ Name:TFR("foo"), Value:TFT(root.attr) }, { Name:TFR("bar"), Value:TFV(Str("baz")) }]` | OBrace NL Id(foo SB:2) Eq(SB:1) Id(root SB:1) Dot Id(attr) NL Id(bar SB:2) Eq(SB:1) OQ(SB:1) QL(baz) CQ NL CBrace |

  Scenario Outline: Generating Tokens for a Function Call
    Given a function name "<function_name>"
    And a list of Token sequences for arguments: <args_token_lists_description>
    When `TokensForFunctionCall` is called with the function name and arguments
    Then the resulting token stream should be: <expected_token_stream>

    Examples:
      | function_name | args_token_lists_description            | expected_token_stream                                                                |
      | "uuid"        | `[]` (empty list)                       | Ident(uuid) OParen CParen                                                            |
      | "strlen"      | `[ TokensForValue(StringVal("hello")) ]`| Ident(strlen) OParen OQuote QuotedLit(hello) CQuote CParen                           |
      | "list"        | `[ TFId("string"), TFId("int") ]`       | Ident(list) OParen Ident(string) Comma Ident(int SB:1) CParen                        |

  Scenario: Consistency between TokensForValue (list/map/object) and TokensForTuple/TokensForObject
    # This scenario covers TestTokenGenerateConsistency
    When generating tokens for a cty.List or cty.Tuple using `TokensForValue`
    And generating tokens for the same logical structure using `TokensForTuple` with `TokensForValue` for elements
    Then the two resulting token streams should be identical
    When generating tokens for a cty.Map or cty.Object using `TokensForValue`
    And generating tokens for the same logical structure using `TokensForObject` with `TokensForIdentifier` for keys (sorted) and `TokensForValue` for values
    Then the two resulting token streams should be identical

    # Notes for token stream representation:
    # - Types: Ident, Num, OQuote, CQuote, QuotedLit, StringLit, OBrack, CBrack, OBrace, CBrace, Comma, Dot, Eq, NL, OParen, CParen, EOF.
    # - (value) or (bytes) indicates token Bytes, e.g., Num(0), Ident(null), QuotedLit(foo).
    # - SB:1 means SpacesBefore:1. NL means Newline token.
    # - `cty_value_string_representation` is a Go-like string describing the cty.Value.
    # - `traversal_description` is a human-readable path like `root.attr["index"]`.
    # - `TokensForValue(StringVal("foo"))` is shorthand for the token sequence for that value. Similar for TFT, TFId.
    # - For object generation, keys are assumed to be sorted alphabetically if not specified otherwise by `TokensForObject` input order.
