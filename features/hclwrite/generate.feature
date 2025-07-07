# This BDD feature file corresponds to the Go files:
# ./hclwrite/generate.go
# ./hclwrite/generate_test.go
#
# It covers the following Go tests:
# - TestTokensForValue
# - TestTokensForTraversal
# - TestTokensForTuple
# - TestTokensForObject
# - TestTokensForFunctionCall
# - TestTokenGenerateConsistency

Feature: HCL Token Generation
  This feature describes the generation of HCL token sequences from various
  Go data structures (cty.Value, hcl.Traversal, etc.) ensuring correct
  HCL syntax representation and formatting.

  Background:
    Given a HCL writing context

  Scenario Outline: Generating Tokens for cty.Value
    The `TokensForValue` function should correctly convert cty.Value types into HCL token sequences.

    Given a cty.Value representing "<value_description>" with value <cty_value_representation>
    When `TokensForValue` is called with this cty.Value
    Then the generated tokens should represent the HCL string "<expected_hcl_string>"

    Examples:
      | value_description        | cty_value_representation             | expected_hcl_string          |
      | Null value               | cty.NullVal(cty.DynamicPseudoType)   | `null`                       |
      | Boolean true             | cty.True                             | `true`                       |
      | Boolean false            | cty.False                            | `false`                      |
      | Number zero              | cty.NumberIntVal(0)                  | `0`                          |
      | Number float             | cty.NumberFloatVal(0.5)              | `0.5`                        |
      | Large Number             | cty.NumberVal(big.NewFloat(8e13))    | `80000000000000`             |
      | Empty string             | cty.StringVal("")                    | `""`                         |
      | Simple string            | cty.StringVal("foo")                 | `"foo"`                      |
      | String with quotes       | cty.StringVal("\"foo\"")              | `"\"foo\""`                  |
      | String with newlines     | cty.StringVal("hello\nworld\n")      | `"hello\\nworld\\n"`         |
      | String with CRLF         | cty.StringVal("hello\r\nworld\r\n")  | `"hello\\r\\nworld\\r\\n"`     |
      | String with backslashes  | cty.StringVal("what\\what")          | `"what\\\\what"`             |
      | String with Unicode 𝄞    | cty.StringVal("𝄞")                   | `"𝄞"`                        |
      | String with Unicode 👩🏾   | cty.StringVal("👩🏾")                 | `"👩🏾"`                       |
      | Empty tuple              | cty.EmptyTupleVal                    | `[]`                         |
      | Tuple with empty tuple   | cty.TupleVal({cty.EmptyTupleVal})    | `[[]]`                       |
      | Empty list (string)      | cty.ListValEmpty(cty.String)         | `[]`                         |
      | Empty set (bool)         | cty.SetValEmpty(cty.Bool)            | `[]`                         |
      | Tuple with one bool      | cty.TupleVal({cty.True})             | `[true]`                     |
      | Tuple with bool, number  | cty.TupleVal({cty.True, cty.NumberIntVal(0)}) | `[true, 0]`              |
      | Empty object             | cty.EmptyObjectVal                   | `{}`                         |
      | Empty map (bool)         | cty.MapValEmpty(cty.Bool)            | `{}`                         |
      | Object one attr          | cty.ObjectVal({"foo": cty.True})     | `{\n  foo = true\n}`         |
      | Object two attrs         | cty.ObjectVal({"bar": cty.NumberIntVal(0), "foo": cty.True}) | `{\n  bar = 0\n  foo = true\n}` | # Order depends on cty iteration
      | Object attr needs quotes | cty.ObjectVal({"foo bar": cty.True}) | `{\n  "foo bar" = true\n}`   |

  Scenario: Generating Tokens for Traversal
    The `TokensForTraversal` function should correctly convert an hcl.Traversal into HCL token sequences.

    Given a traversal representing "root.attr[\"index\"]"
    When `TokensForTraversal` is called with this traversal
    Then the generated tokens should represent the HCL string "root.attr[\"index\"]"

  Scenario Outline: Generating Tokens for Tuple Constructors
    The `TokensForTuple` function should correctly create HCL tuple constructor tokens.

    Given a list of HCL token sequences for tuple elements "<elements_description>"
    When `TokensForTuple` is called with these element tokens
    Then the generated tokens should represent the HCL string "<expected_hcl_string>"

    Examples:
      | elements_description         | expected_hcl_string |
      | No elements                  | `[]`                |
      | One string element "foo"     | `["foo"]`           |
      | Two elements: root.attr, "foo" | `[root.attr, "foo"]` |

  Scenario Outline: Generating Tokens for Object Constructors
    The `TokensForObject` function should correctly create HCL object constructor tokens.

    Given a list of object attribute tokens "<attributes_description>"
    When `TokensForObject` is called with these attribute tokens
    Then the generated tokens should represent the HCL string "<expected_hcl_string>"

    Examples:
      | attributes_description             | expected_hcl_string                |
      | No attributes                      | `{}`                               |
      | One attribute: bar = "baz"         | `{\n  bar = "baz"\n}`              |
      | Two attributes: foo = root.attr, bar = "baz" | `{\n  foo = root.attr\n  bar = "baz"\n}` |

  Scenario Outline: Generating Tokens for Function Calls
    The `TokensForFunctionCall` function should correctly create HCL function call tokens.

    Given a function name "<func_name>" and argument tokens "<args_description>"
    When `TokensForFunctionCall` is called
    Then the generated tokens should represent the HCL string "<expected_hcl_string>"

    Examples:
      | func_name | args_description        | expected_hcl_string    |
      | uuid      | No arguments            | `uuid()`               |
      | strlen    | One arg "hello"         | `strlen("hello")`      |
      | list      | Two args: string, int   | `list(string, int)`    |

  Scenario: Consistency for Tuple Token Generation
    Generating tokens for a tuple structure using `TokensForValue` (with cty.ListVal or cty.TupleVal)
    should produce the same HCL token sequence as using `TokensForTuple` with equivalent element tokens.

    Given a list of cty.Value elements for a tuple
    When tokens are generated using `TokensForValue` with a cty.ListVal from these elements
    And tokens are generated using `TokensForValue` with a cty.TupleVal from these elements
    And tokens are generated using `TokensForTuple` with `TokensForValue` for each element
    Then all three resulting token sequences should be identical

  Scenario: Consistency for Object Token Generation
    Generating tokens for an object structure using `TokensForValue` (with cty.MapVal or cty.ObjectVal)
    should produce the same HCL token sequence as using `TokensForObject` with equivalent, sorted attribute tokens.

    Given a map of string keys to cty.Value attributes for an object
    When tokens are generated using `TokensForValue` with a cty.MapVal from this map
    And tokens are generated using `TokensForValue` with a cty.ObjectVal from this map
    And tokens are generated using `TokensForObject` with attribute names as identifiers and `TokensForValue` for each value, with keys sorted alphabetically
    Then all three resulting token sequences should be identical
```
