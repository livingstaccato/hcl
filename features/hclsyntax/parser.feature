# Covers tests in ./hclsyntax/parser_test.go
# Specifically, TestParseConfig and TestParseConfigDiagnostics

Feature: HCL Syntax - Configuration Parsing
  This feature tests the `ParseConfig` function, which parses HCL configuration
  from a byte slice into an HCL AST (Abstract Syntax Tree), specifically focusing
  on the structure of the `Body` and its contained `Attributes` and `Blocks`.
  It also verifies correct diagnostic reporting for syntax errors and
  structural issues.

  Scenario Outline: Parsing HCL configuration inputs
    Given an HCL input string: "<input_hcl>"
    When the input string is parsed using `ParseConfig` with filename "<filename>" and initial position L1C1B0
    Then the number of diagnostics should be <diagnostics_count>
    And the parsed `File.Body` should have structure:
      | BodyProperty      | Value                                   |
      | Attributes        | <expected_attrs_map_repr>               |
      | Blocks            | <expected_blocks_list_repr>             |
      | SrcRange          | <expected_body_src_range>               |
      | EndRange          | <expected_body_end_range>               |
    And for each attribute in `File.Body.Attributes`:
      | AttrName | ExprType            | ExprValue (if literal) | ExprSrcRange      | AttrSrcRange      | NameRange         | EqualsRange       |
      | <AName>  | <AExprType>         | <AExprVal>             | <AExprSR>         | <ASR>             | <ANR>             | <AER>             |
      # ... more rows for more attributes
    And for each block in `File.Body.Blocks`:
      | BlockType | Labels (list) | Body.SrcRange     | Body.EndRange     | TypeRange         | LabelRanges (list) | OpenBraceRange    | CloseBraceRange   |
      | <BType>   | <BLabels>     | <BBodySR>         | <BBodyER>         | <BTypeR>          | <BLabelRs>         | <BOpenBR>         | <BCloseBR>        |
      # ... more rows for more blocks (nested bodies are not detailed here but their ranges are)

    Examples:
      # Basic structures
      | input_hcl           | filename  | diagnostics_count | expected_attrs_map_repr | expected_blocks_list_repr | expected_body_src_range | expected_body_end_range |
      | `""`                | ""        | 0                 | {}                      | []                        | L1C1B0-L1C1B0           | L1C1B0-L1C1B0           |
      | `"block {}\\n"`     | ""        | 0                 | {}                      | [Block(block)]            | L1C1B0-L2C1B9           | L2C1B9-L2C1B9           |
      | `"block {}"`        | ""        | 0                 | {}                      | [Block(block)]            | L1C1B0-L1C9B8           | L1C9B8-L1C9B8           |
      | `"block {}block {}\\n"`| ""     | 1                 | {}                      | [Block(block)]            | L1C1B0-L2C1B17          | L2C1B17-L2C1B17         | # Missing newline
      | `"block { block {} }\\n"`| ""   | 1                 | {}                      | [Block(block)]            | L1C1B0-L2C1B19          | L2C1B19-L2C1B19         | # Invalid single-line nesting
      | `"block \\"foo\\" {}\\n"`| ""   | 0                 | {}                      | [Block(block L:"foo")]    | L1C1B0-L2C1B15          | L2C1B15-L2C1B15         |
      | `"block foo {}\\n"` | ""        | 0                 | {}                      | [Block(block L:"foo")]    | L1C1B0-L2C1B13          | L2C1B13-L2C1B13         |
      | `"a = 1\\n"`        | ""        | 0                 | {a:Attr}                | []                        | L1C1B0-L2C1B6           | L2C1B6-L2C1B6           |
      | `"a = \\"h ${true}\\"\\n"`| ""  | 0                 | {a:Attr}                | []                        | L1C1B0-L2C1B20          | L2C1B20-L2C1B20         |
      | `"a = foo.bar\\n"`  | ""        | 0                 | {a:Attr}                | []                        | L1C1B0-L2C1B12          | L2C1B12-L2C1B12         |
      # Comments
      | `"a = 1 # comment\\n"`| ""    | 0                 | {a:Attr}                | []                        | L1C1B0-L2C1B21          | L2C1B21-L2C1B21         |
      # For expressions
      | `"a = [for k,v in f:v if t]\\n"`| ""| 0             | {a:Attr}                | []                        | L1C1B0-L2C1B33          | L2C1B33-L2C1B33         |
      # Incomplete function calls (specific diagnostics tested in another scenario)
      | `attr = object({ foo = })\nattr2 = "foo"\n` | "" | 1 (Missing value for attribute) | {attr:Attr,attr2:Attr} | [] | L1C1B0-L3C1B39 | L3C1B39-L3C1B39 |
      | `block "l"{\n attr = o(\n` | "" | 2 (Missing expr, Unclosed block) | {} | [Block(block L:"l")] | L1C1B0-L3C1B22 | L3C1B22-L3C1B22 |


    # Attribute details for "a = 1\\n"
    Then for attribute "a":
      | AttrName | ExprType         | ExprValue (if literal) | ExprSrcRange    | AttrSrcRange    | NameRange     | EqualsRange   |
      | a        | LiteralValueExpr | NumberIntVal(1)        | L1C5B4-L1C6B5   | L1C1B0-L1C6B5   | L1C1B0-L1C2B1 | L1C3B2-L1C4B3 |

    # Block details for "block {}\\n"
    Then for block "block" at index 0:
      | BlockType | Labels (list) | Body.SrcRange   | Body.EndRange   | TypeRange     | LabelRanges (list) | OpenBraceRange | CloseBraceRange |
      | block     | []            | L1C7B6-L1C9B8   | L1C9B8-L1C9B8   | L1C1B0-L1C6B5 | []                 | L1C7B6-L1C8B7  | L1C8B7-L1C9B8   |

  Scenario Outline: Parsing HCL configurations with specific diagnostic expectations
    Given an HCL input string: "<input_hcl>"
    When the input string is parsed using `ParseConfig` with filename "test.hcl" and initial position L1C1B0
    Then the diagnostics should contain an error with Summary "<summary>" and Detail "<detail>" and Subject <subject_range>

    Examples:
      | input_hcl                                     | summary                                      | detail                                                                                                                               | subject_range   |
      | `"blah {\\n"`                                  | Unclosed configuration block                 | There is no closing brace for this block before the end of the file. This may be caused by incorrect brace nesting elsewhere in this file. | L1C6B5-L1C7B6   |
      | `"blah {\\n  a = 1\\n"`                         | Unclosed configuration block                 | There is no closing brace for this block before the end of the file. This may be caused by incorrect brace nesting elsewhere in this file. | L1C6B5-L1C7B6   |
      | `"blah {"`                                    | Unclosed configuration block                 | There is no closing brace for this block before the end of the file. This may be caused by incorrect brace nesting elsewhere in this file. | L1C6B5-L1C7B6   |
      | `"blah { a = 1"`                              | Unclosed configuration block                 | There is no closing brace for this block before the end of the file. This may be caused by incorrect brace nesting elsewhere in this file. | L1C6B5-L1C7B6   |
      | `"foo = { a = 1"`                             | Unterminated object constructor expression   | There is no corresponding closing brace before the end of the file. This may be caused by incorrect brace nesting elsewhere in this file. | L1C7B6-L1C8B7   |
      | `"foo = [ a"`                                 | Unterminated tuple constructor expression    | There is no corresponding closing bracket before the end of the file. This may be caused by incorrect bracket nesting elsewhere in this file. | L1C7B6-L1C8B7   |
      | `"foo = boop(\\"a\\""`                         | Unterminated function call                   | There is no closing parenthesis for this function call before the end of the file. This may be caused by incorrect parenthesis nesting elsewhere in this file. | L1C7B6-L1C12B11 |
      | `"foo = (1"`                                  | Unbalanced parentheses                       | Expected a closing parenthesis to terminate the expression.                                                                            | L1C9B8-L1C9B8   |
      | `"foo = \\"${a"`                               | Unclosed template interpolation sequence     | There is no closing brace for this interpolation sequence before the end of the file. This might be caused by incorrect nesting inside the given expression. | L1C8B7-L1C10B9  |
      | `"foo = \\"${a\\""`                             | Unclosed template interpolation sequence     | There is no closing brace for this interpolation sequence before the end of the quoted template. This might be caused by incorrect nesting inside the given expression. | L1C8B7-L1C10B9  |
      | `"foo = \\"${a}"` # error is unterminated string | Unterminated template string                 | No closing marker was found for the string.                                                                                              | L1C12B11-L1C12B11|
      | `"foo = {"`                                   | Missing expression                           | Expected the start of an expression, but found the end of the file.                                                                  | L1C8B7-L1C8B7   |
      | `"foo = ["`                                   | Missing expression                           | Expected the start of an expression, but found the end of the file.                                                                  | L1C8B7-L1C8B7   |
      | `"foo = foo("`                                | Missing expression                           | Expected the start of an expression, but found the end of the file.                                                                  | L1C11B10-L1C11B10|

    # Notes for table values:
    # - Input HCL strings are Go-escaped for newlines, quotes.
    # - {} for attrs_map_repr means empty map. [] for blocks_list_repr means empty list.
    # - Attr means a hcl.Attribute struct. Block(type L:labels) means a hcl.Block.
    # - Ranges LxCxB-LxCxB mean Line x, Col x, Byte x for Start and End.
    # - ExprType and ExprValue help define the expected expression on an attribute.
    # - For complex expressions like templates or traversals, only ExprType might be specified for brevity,
    #   with the understanding that the internal structure matches the Go test's expectations.
    # - For the diagnostics scenario, only the Summary, Detail, and Subject range are checked for the primary error.
    #   The Context range is also checked if present in the Go test's expected diagnostic.
    # - Some complex struct definitions from the Go test (like for range checking in `TestParseConfig_incompleteFunctionCall`) are simplified in Gherkin.
    #   The core idea is that the parser correctly recovers and parses subsequent valid elements.
