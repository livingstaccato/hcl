# Covers internal JSON parsing logic in ./json/parser.go
# Based on test cases in ./json/parser_test.go (TestParse, TestParseWithPos)

Feature: HCL JSON Low-Level AST Parser
  This feature tests the internal low-level parser for HCL's JSON syntax.
  It verifies the correct parsing of various JSON inputs into an internal Abstract
  Syntax Tree (AST) of `json.node` implementations (e.g., `objectVal`, `arrayVal`,
  `stringVal`, etc.), including accurate source range tracking for all nodes
  and diagnostic reporting for syntactical errors.

  Scenario Outline: Parsing various JSON value inputs
    Given a JSON input string: "<input_json_string>"
    When the input is parsed using the internal `parseFileContent` function with filename "" and initial position L1C1B0
    Then the number of diagnostics should be <expected_diag_count>
    And the root of the resulting AST node should be of type <expected_root_node_type>
    And its source range should be <expected_root_node_range>
    And its specific properties should match: <expected_node_properties_details>
      # <expected_node_properties_details> will describe specific fields like Value for primitives,
      # Attrs for objectVal (name, value node type, value range, name range),
      # Values for arrayVal (element node type, element range),
      # OpenRange, CloseRange for objects/arrays.

    Examples:
      # Primitive Literals
      | input_json_string | expected_diag_count | expected_root_node_type | expected_root_node_range | expected_node_properties_details                                           |
      | `true`            | 0                   | `*json.booleanVal`      | L1C1B0-L1C5B4            | Value:true                                                                 |
      | `false`           | 0                   | `*json.booleanVal`      | L1C1B0-L1C6B5            | Value:false                                                                |
      | `null`            | 0                   | `*json.nullVal`         | L1C1B0-L1C5B4            | (no specific value field)                                                  |
      | `"hello"`         | 0                   | `*json.stringVal`       | L1C1B0-L1C8B7            | Value:"hello"                                                              |
      | `123`             | 0                   | `*json.numberVal`       | L1C1B0-L1C4B3            | Value:123 (BigFloat)                                                       |
      | `-1.5e2`          | 0                   | `*json.numberVal`       | L1C1B0-L1C7B6            | Value:-150 (BigFloat)                                                      |
      # Arrays
      | `[]`              | 0                   | `*json.arrayVal`        | L1C1B0-L1C3B2            | Values:[], OpenRange:L1C1B0-L1C2B1                                          |
      | `[true, "a"]`     | 0                   | `*json.arrayVal`        | L1C1B0-L1C13B12          | Values:[{Type:*json.booleanVal, Range:L1C2B1-L1C6B5, Value:true}, {Type:*json.stringVal, Range:L1C8B7-L1C12B11, Value:"a"}], OpenRange:L1C1B0-L1C2B1 |
      # Objects
      | `{}`              | 0                   | `*json.objectVal`       | L1C1B0-L1C3B2            | Attrs:[], OpenRange:L1C1B0-L1C2B1, CloseRange:L1C2B1-L1C3B2                   |
      | `{"key": 1}`      | 0                   | `*json.objectVal`       | L1C1B0-L1C11B10          | Attrs:[{Name:"key", NameRange:L1C2B1-L1C7B6, ValueNode:{Type:*json.numberVal, Range:L1C9B8-L1C10B9, Value:1}}], OpenRange:L1C1B0-L1C2B1, CloseRange:L1C10B9-L1C11B10 |
      # Error Cases (Syntax)
      | `undefined`       | 1                   | `json.invalidVal`       | L1C1B0-L1C10B9           | (Error: Invalid JSON keyword)                                              |
      | `"unterminated`   | 1                   | `json.invalidVal`       | L1C1B0-L1C14B13          | (Error: Invalid JSON string - unterm)                                      |
      | `1 2`             | 1                   | `*json.numberVal`       | L1C1B0-L1C2B1            | Value:1 (Error: Extraneous data after value)                               |
      | `{"key":true,]`   | 1                   | `json.invalidVal`       | L1C1B0-L1C2B1            | (Error: Trailing comma in object)                                          | # Root node becomes invalid due to error
      | `[1,}`            | 1                   | `json.invalidVal`       | L1C1B0-L1C2B1            | (Error: Trailing comma in array)                                           | # Root node becomes invalid
      | `{"key"}`         | 1                   | `json.invalidVal`       | L1C1B0-L1C2B1            | (Error: Missing property value colon)                                      |
      | `[true false]`    | 1                   | `json.invalidVal`       | L1C1B0-L1C2B1            | (Error: Missing attribute separator comma for array)                       |

  Scenario: Parsing a JSON value with a specific start position
    Given a JSON input string: `true`
    And a starting hcl.Pos: Line 3, Column 10, Byte 0
    When the input is parsed using `parseFileContent` with this start position and filename "offset.json"
    Then the number of diagnostics should be 0
    And the root of the resulting AST node should be of type `*json.booleanVal` with Value:true
    And its source range should be Filename:"offset.json" Start:L3C10B0 End:L3C14B4

    # Notes for table values:
    # - Node type string e.g. `*json.booleanVal`. `json.invalidVal` for error nodes.
    # - Source ranges are L<Line>C<Col>B<Byte>-L<Line>C<Col>B<Byte>.
    # - `expected_node_properties_details`:
    #   - For primitives: `Value:<val_repr>`
    #   - For arrays: `Values:[{Type:..., Range:..., Value:...}, ...], OpenRange:...`
    #   - For objects: `Attrs:[{Name:..., NameRange:..., ValueNode:{Type:..., Range:..., Value:...}}, ...], OpenRange:..., CloseRange:...`
    #   - For error cases, it might describe the error or that the node is an `invalidVal`.
    # - The details of source ranges for nested elements inside arrays/objects are important and asserted by the Go test.
    #   This Gherkin simplifies some of that for readability but aims to capture the essence.
    # - The `invalidVal` type is unexported, so using `json.invalidVal` in Gherkin for type.
