# Covers public API functions in ./json/public.go
# Based on test cases in ./json/public_test.go

Feature: HCL JSON Parser Public API
  This feature tests the public API functions of the `json` package for parsing
  HCL configurations and expressions written in JSON syntax. It covers parsing
  from byte slices and files, handling of start positions for source range accuracy,
  template evaluation within JSON strings, and error reporting.

  Scenario: Parsing a JSON document whose root is not an object or array
    Given a JSON input string: `true`
    And filename "test.json"
    When `json.Parse` is called with this input and filename
    Then 1 diagnostic should be reported
    And the diagnostic summary should be "Root value must be object"
    And the diagnostic detail should contain "must be either a JSON object or a JSON array of objects"
    And a non-nil `hcl.File` object should be returned (with a placeholder body)

  Scenario: Parsing and evaluating a JSON string attribute with HCL template interpolation
    Given a JSON input string: `{"greeting": "hello ${world_var}"}` and filename "test.json"
    And an `hcl.EvalContext` with variable "world_var" = StringVal("world")
    When `json.Parse` is called with the input and filename
    Then no parse diagnostics should be reported
    And an `hcl.File` object "ParsedFile" is returned
    When attributes are extracted from "ParsedFile.Body" using `JustAttributes`
    Then no attribute extraction diagnostics should be reported
    And attribute "greeting" should exist
    When the expression for attribute "greeting" is evaluated with the EvalContext
    Then no evaluation diagnostics should be reported
    And the resulting cty.Value should be StringVal("hello world")

  Scenario: Parsing and evaluating a JSON string attribute that unwraps to a non-string type
    Given a JSON input string: `{"is_enabled": "${true}"}` and filename "test.json"
    And an empty `hcl.EvalContext`
    When `json.Parse` is called with the input and filename
    Then no parse diagnostics should be reported
    And an `hcl.File` object "ParsedFile" is returned
    When attributes are extracted from "ParsedFile.Body"
    And the expression for attribute "is_enabled" is evaluated with the EvalContext
    Then no evaluation diagnostics should be reported
    And the resulting cty.Value should be cty.True

  Scenario: Parsing a malformed JSON document
    Given a malformed JSON input string: `{"key": "value",,}` (extra comma) and filename "error.json"
    When `json.Parse` is called with the input and filename
    Then 2 diagnostics should be reported (e.g., "Unexpected token COMMA" and "Expected a property key")
    And a non-nil `hcl.File` object should be returned

  Scenario: Parsing a JSON document fragment with a specified start position
    Given a full JSON source string: `{\n  "foo": {\n    "bar": "baz"\n  }\n}`
    And a partial JSON source string: `{\n    "bar": "baz"\n  }`
    And the start position of the partial string within the full string is Line 2, Column 10, Byte N (actual byte offset depends on content before it)
    When the full JSON source is parsed as "full.json"
    And its "foo" block's "bar" attribute expression range is "RangeFull"
    When the partial JSON source is parsed as "part.json" using `json.ParseWithStartPos` and the specified start position
    And its "bar" attribute expression range is "RangePart"
    Then "RangePart" should be equal to "RangeFull" (verifying correct offset application)
    And no parse diagnostics should be reported for either operation

  Scenario Outline: Parsing and evaluating standalone JSON expressions
    Given a JSON expression string: "<json_expression>"
    And an `hcl.EvalContext` "Ctx" with variable "noun" = StringVal("world")
    When `json.ParseExpression` is called with "<json_expression>" and filename "expr.json"
    Then no parse diagnostics should be reported
    When the parsed `hcl.Expression` is evaluated with "Ctx"
    Then no evaluation diagnostics should be reported
    And the resulting cty.Value should be <expected_cty_value_repr>

    Examples:
      | json_expression   | expected_cty_value_repr                                           |
      | `"hello"`         | `StringVal("hello")`                                              |
      | `"hello ${noun}"` | `StringVal("hello world")`                                        |
      | `true`            | `True`                                                            |
      | `1`               | `NumberIntVal(1)`                                                 |
      | `{}`              | `EmptyObjectVal`                                                  |
      | `{"foo":"bar"}`   | `ObjectVal({"foo":StringVal("bar")})`                             |
      | `[]`              | `EmptyTupleVal`                                                   |
      | `["1",2]`         | `TupleVal([StringVal("1"), NumberIntVal(2)])`                     |

  Scenario: Parsing a malformed standalone JSON expression
    Given a JSON expression string: `invalid_keyword`
    When `json.ParseExpression` is called with this string and filename "badexpr.json"
    Then 1 diagnostic should be reported
    And its summary should contain "Invalid JSON keyword"
    And a non-nil `hcl.Expression` object should still be returned (representing the invalid expression)

  Scenario: Parsing a JSON expression fragment with a specified start position
    Given a full JSON source string for an object: `{\n  "key": "value_fragment"\n}`
    And a partial JSON string representing only the value: `"value_fragment"`
    And the start position of the partial string within the full string is Line 2, Column 10, Byte M
    When the "key" attribute's expression from parsing the full JSON has range "RangeFullExpr"
    And the partial JSON string is parsed using `json.ParseExpressionWithStartPos` with the specified start position, yielding "PartExpr"
    Then "PartExpr.Range()" should be equal to "RangeFullExpr"
    And no parse diagnostics should be reported for either operation

  Scenario: Parsing a valid JSON file using ParseFile
    Given a file named "valid_config.json" with content: `{"message": "Hello from file!"}`
    When `json.ParseFile("valid_config.json")` is called
    Then a non-nil `hcl.File` "ParsedFile" should be returned
    And no diagnostics should be reported
    And "ParsedFile.Body" should have an attribute "message" with string value "Hello from file!"

  Scenario Outline: Parsing a non-existent or unreadable file using ParseFile
    Given the file operation for "<filename>" will result in "<file_error_type>"
    When `json.ParseFile("<filename>")` is called
    Then a nil `hcl.File` should be returned
    And diagnostics should be reported
    And the first diagnostic summary should be "<expected_summary>"
    And the first diagnostic detail should contain "<expected_detail_contains>"

    Examples:
      | filename      | file_error_type | expected_summary     | expected_detail_contains        |
      | "nonexist.json" | NotExist        | "Failed to open file"| "could not be opened"           |
      | "unreadable.json"| ReadError     | "Failed to read file"| "error occured while reading it"|
      # Note: Simulating "close error" is harder and less common for BDD.

    # Notes for tables:
    # - cty.Value representations are simplified (e.g., `StringVal("text")`).
    # - Byte offsets (Byte N, Byte M) are placeholders for actual calculated byte offsets.
    # - The `file_error_type` in the last scenario dictates the mock behavior of os.Open/ReadAll.
