# Covers tests in ./json/parser_test.go
# Specifically, TestParse and TestParseWithPos

Feature: JSON HCL Low-Level Parser
  This feature tests the low-level `parser` for HCL's JSON syntax.
  It verifies the correct parsing of various JSON constructs into an internal
  node structure, including proper source range tracking and diagnostic reporting
  for valid and invalid inputs.

  Scenario Outline: Parsing various JSON inputs
    Given a JSON input string: "<input_json>"
    When the input is parsed
    Then the number of diagnostics should be <diagnostics_count>
    And the resulting node structure should be <expected_node_structure> with source range <expected_source_range>
    And if the node is an object, its open brace range should be <open_brace_range> and close brace range <close_brace_range>
    And if the node is an array, its open bracket range should be <open_bracket_range>

    Examples:
      # Simple values
      | input_json        | diagnostics_count | expected_node_structure | expected_source_range | open_brace_range | close_brace_range | open_bracket_range |
      | `true`            | 0                 | Boolean(true)           | L1C1-L1C5 (B0-B4)     |                  |                   |                    |
      | `false`           | 0                 | Boolean(false)          | L1C1-L1C6 (B0-B5)     |                  |                   |                    |
      | `null`            | 0                 | Null                    | L1C1-L1C5 (B0-B4)     |                  |                   |                    |
      | `undefined`       | 1                 | Invalid                 | L1C1-L1C10 (B0-B9)    |                  |                   |                    | # Invalid JSON keyword
      | `flase`           | 1                 | Invalid                 | L1C1-L1C6 (B0-B5)     |                  |                   |                    | # Typo for false
      | `"hello"`         | 0                 | String("hello")         | L1C1-L1C8 (B0-B7)     |                  |                   |                    |
      | `"hello\\nworld"` | 0                 | String("hello\nworld")  | L1C1-L1C15 (B0-B14)   |                  |                   |                    |
      | `"hello \\"world\\""`| 0               | String("hello \"world\"") | L1C1-L1C18 (B0-B17)   |                  |                   |                    |
      | `"hello \\\\"`    | 0                 | String("hello \\")      | L1C1-L1C11 (B0-B10)   |                  |                   |                    |
      | `"hello`          | 1                 | Invalid                 | L1C1-L1C7 (B0-B6)     |                  |                   |                    | # Unterminated string
      | `"he\\llo"`       | 1                 | Invalid                 | L1C1-L1C9 (B0-B8)     |                  |                   |                    | # Invalid escape sequence
      | `1`               | 0                 | Number(1)               | L1C1-L1C2 (B0-B1)     |                  |                   |                    |
      | `1.2`             | 0                 | Number(1.2)             | L1C1-L1C4 (B0-B3)     |                  |                   |                    |
      | `-1`              | 0                 | Number(-1)              | L1C1-L1C3 (B0-B2)     |                  |                   |                    |
      | `1.2e5`           | 0                 | Number(120000)          | L1C1-L1C6 (B0-B5)     |                  |                   |                    |
      | `1.2e+5`          | 0                 | Number(120000)          | L1C1-L1C7 (B0-B6)     |                  |                   |                    |
      | `1.2e-5`          | 0                 | Number(1.2e-5)          | L1C1-L1C7 (B0-B6)     |                  |                   |                    |
      | `.1`              | 1                 | Invalid                 | L1C1-L1C3 (B0-B2)     |                  |                   |                    | # Invalid number format
      | `+2`              | 1                 | Invalid                 | L1C1-L1C3 (B0-B2)     |                  |                   |                    | # Invalid number format
      | `1 2`             | 1                 | Number(1)               | L1C1-L1C2 (B0-B1)     |                  |                   |                    | # Trailing content after number
      # Objects
      | `{}`              | 0                 | Object([])              | L1C1-L1C3 (B0-B2)     | L1C1-L1C2 (B0-B1) | L1C2-L1C3 (B1-B2) |                    |
      | `{"hello": true}` | 0                 | Object([Attr("hello",Bool(true),L1C11-L1C15,L1C2-L1C9)]) | L1C1-L1C16 (B0-B15) | L1C1-L1C2 (B0-B1) | L1C15-L1C16 (B14-B15) |    |
      | `{"hello": true, "bye": false}` | 0   | Object([Attr("hello",Bool(true),L1C11-L1C15,L1C2-L1C9), Attr("bye",Bool(false),L1C24-L1C29,L1C17-L1C22)]) | L1C1-L1C30 (B0-B29) | L1C1-L1C2 (B0-B1) | L1C29-L1C30 (B28-B29) | |
      | `{"hello":true`   | 1                 | Invalid                 | L1C1-L1C2 (B0-B1)     |                  |                   |                    | # Missing closing brace
      | `{"hello":true]`   | 1                 | Invalid                 | L1C1-L1C2 (B0-B1)     |                  |                   |                    | # Mismatched closing bracket
      | `{"hello":true,}`  | 1                 | Invalid                 | L1C1-L1C2 (B0-B1)     |                  |                   |                    | # Trailing comma in object
      | `{true:false}`     | 1                 | Invalid                 | L1C1-L1C2 (B0-B1)     |                  |                   |                    | # Object key not a string
      | `{"hello": true, "hello": true}` | 0  | Object([Attr("hello",Bool(true),L1C11-L1C15,L1C2-L1C9), Attr("hello",Bool(true),L1C26-L1C30,L1C17-L1C24)]) | L1C1-L1C31 (B0-B30) | L1C1-L1C2 (B0-B1) | L1C30-L1C31 (B29-B30) | # Duplicate keys allowed by parser
      | `{"hello": true, "hello", true}` | 1  | Invalid                 | L1C1-L1C2 (B0-B1)     |                  |                   |                    | # Comma instead of colon
      | `{"hello", "world"}` | 1             | Invalid                 | L1C1-L1C2 (B0-B1)     |                  |                   |                    | # Missing colon
      # Arrays
      | `[]`              | 0                 | Array([])               | L1C1-L1C3 (B0-B2)     |                  |                   | L1C1-L1C2 (B0-B1)  |
      | `[true]`          | 0                 | Array([Bool(true,L1C2-L1C6)]) | L1C1-L1C7 (B0-B6)     |                  |                   | L1C1-L1C2 (B0-B1)  |
      | `[true, false]`   | 0                 | Array([Bool(true,L1C2-L1C6), Bool(false,L1C8-L1C13)]) | L1C1-L1C14 (B0-B13) |                  |                   | L1C1-L1C2 (B0-B1)  |
      | `[[]]`            | 0                 | Array([Array([],L1C2-L1C4,L1C2-L1C3)]) | L1C1-L1C5 (B0-B4)     |                  |                   | L1C1-L1C2 (B0-B1)  |
      | `[`               | 2                 | Invalid                 | L1C1-L1C2 (B0-B1)     |                  |                   |                    | # Unterminated array
      | `[true`           | 1                 | Invalid                 | L1C1-L1C2 (B0-B1)     |                  |                   |                    | # Unterminated array after element
      | `]`               | 1                 | Invalid                 | L1C1-L1C2 (B0-B1)     |                  |                   |                    | # Unexpected closing bracket
      | `[true,]`         | 1                 | Invalid                 | L1C1-L1C2 (B0-B1)     |                  |                   |                    | # Trailing comma in array
      | `[[],]`           | 1                 | Invalid                 | L1C1-L1C2 (B0-B1)     |                  |                   |                    | # Trailing comma after nested array
      | `["hello":true]`  | 1                 | Invalid                 | L1C1-L1C2 (B0-B1)     |                  |                   |                    | # Colon in array
      | `[true}`          | 1                 | Invalid                 | L1C1-L1C2 (B0-B1)     |                  |                   |                    | # Mismatched closing brace
      # Object property syntax errors
      | `{"wrong"=true}`  | 1                 | Invalid                 | L1C1-L1C2 (B0-B1)     |                  |                   |                    | # Equals instead of colon
      | `{"wrong" = true}`| 1                 | Invalid                 | L1C1-L1C2 (B0-B1)     |                  |                   |                    | # Equals with spaces
      | `{"wrong" true}`  | 1                 | Invalid                 | L1C1-L1C2 (B0-B1)     |                  |                   |                    | # Missing colon

  Scenario: Parsing with a specific start position
    Given a JSON input string: "true"
    And a start position of Line 3, Column 10, Byte 0
    When the input is parsed with this start position
    Then the number of diagnostics should be 0
    And the resulting node structure should be Boolean(true)
    And its source range should be L3C10-L3C14 (B0-B4)

  # Notes on <expected_node_structure> format:
  # - Boolean(value): booleanVal{Value: value, SrcRange: ...}
  # - Null: nullVal{SrcRange: ...}
  # - Invalid: invalidVal{SrcRange: ...}
  # - String(value): stringVal{Value: value, SrcRange: ...}
  # - Number(value): numberVal{Value: big.Float(value), SrcRange: ...}
  # - Object([Attr(name, valueNode, valueRange, nameRange), ...]): objectVal{Attrs: [...], SrcRange: ..., OpenRange: ..., CloseRange: ...}
  # - Array([valueNode, ...]): arrayVal{Values: [...], SrcRange: ..., OpenRange: ...}
  # - Source ranges like L1C1-L1C5 (B0-B4) denote Line 1, Col 1 to Line 1, Col 5 (Byte 0 to Byte 4).
  # - For Object attributes (Attr), valueNode is the parsed node for the attribute's value, valueRange is its source range, and nameRange is the source range of the attribute's name string.
  # - For Array elements, valueNode is the parsed node for the element, and its source range is part of the node itself.
