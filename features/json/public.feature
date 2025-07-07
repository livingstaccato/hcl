# Covers tests in ./json/public_test.go
# Specifically, TestParse_nonObject, TestParseTemplate, TestParseTemplateUnwrap,
# TestParse_malformed, TestParseWithStartPos, TestParseExpression,
# TestParseExpression_malformed, and TestParseExpressionWithStartPos

Feature: JSON HCL Parsing Public API
  This feature tests the public API for parsing HCL represented in JSON format.
  It covers parsing entire JSON documents (which must be objects at the root),
  parsing JSON expressions, handling templates within JSON strings,
  and the correct reporting of diagnostics and source ranges, including
  when using `ParseWithStartPos` and `ParseExpressionWithStartPos`.

  Scenario: Parsing a JSON document that is not a root object
    Given a JSON input string: "true"
    When `json.Parse` is called with this input
    Then 1 diagnostic should be reported
    And a non-nil File object should be returned
    And the File object's Body should not be nil
    And the File object's Body should represent a placeholder object

  Scenario: Parsing and evaluating a JSON string with a template interpolation
    Given a JSON input string: `{"greeting": "hello ${\"world\"}"}`
    When `json.Parse` is called with this input
    Then no parse diagnostics should be reported
    And a non-nil File object with a non-nil Body should be returned
    When attributes are extracted from the Body
    Then no decode diagnostics should be reported
    And the "greeting" attribute's expression, when evaluated with an empty context, should result in "hello world" (string)
    And no evaluation diagnostics should be reported

  Scenario: Parsing and evaluating a JSON string with template unwrap
    Given a JSON input string: `{"greeting": "${true}"}`
    When `json.Parse` is called with this input
    Then no parse diagnostics should be reported
    When attributes are extracted from the Body
    Then no decode diagnostics should be reported
    And the "greeting" attribute's expression, when evaluated with an empty context, should result in true (boolean)
    And no evaluation diagnostics should be reported

  Scenario: Parsing a malformed JSON document
    Given a JSON input string:
      """
      {
        "http_proxy_url: "http://xxxxxx",
      }
      """
    When `json.Parse` is called with this input
    Then 2 diagnostics should be reported
    And the diagnostics error message should contain "Missing property value colon"
    And a non-nil File object should be returned

  Scenario: Parsing with Start Position for correct range mapping
    Given a full JSON source string:
      """
      {
        "foo": {
          "bar": "baz"
        }
      }
      """
    And a partial JSON source string representing the inner object's value:
      """
      {
        "bar": "baz"
      }
      """
    And the start position of the partial string within the full string is Line 2, Column 10
    When the full JSON source is parsed using `json.Parse`
    And the partial JSON source is parsed using `json.ParseWithStartPos` with the calculated start position
    Then no parse diagnostics should be reported for either parsing operation
    And the source range of the "bar" attribute's expression from the "foo" block in the full parse
    Should be equal to the source range of the "bar" attribute's expression from the partial parse

  Scenario Outline: Parsing various JSON expressions
    Given a JSON expression string: "<expression_json>"
    And an evaluation context with variable "noun" set to "world" (string)
    When `json.ParseExpression` is called with this input
    Then no parse diagnostics should be reported (unless it's a malformed case)
    And the expression, when evaluated with the context, should result in <expected_cty_value_string>
    And no evaluation diagnostics should be reported

    Examples:
      | expression_json     | expected_cty_value_string                                         |
      | `"hello"`           | cty.StringVal("hello")                                            |
      | `"hello ${noun}"`   | cty.StringVal("hello world")                                      |
      | `true`              | cty.True                                                          |
      | `false`             | cty.False                                                         |
      | `1`                 | cty.NumberIntVal(1)                                               |
      | `{}`                | cty.EmptyObjectVal                                                |
      | `{"foo":"bar","baz":1}` | cty.ObjectVal(map[string]cty.Value{"baz":cty.NumberIntVal(1), "foo":cty.StringVal("bar")}) |
      | `[]`                | cty.EmptyTupleVal                                                 |
      | `["1",2,3]`         | cty.TupleVal([]cty.Value{cty.StringVal("1"), cty.NumberIntVal(2), cty.NumberIntVal(3)}) |

  Scenario: Parsing a malformed JSON expression
    Given a JSON expression string: "invalid"
    When `json.ParseExpression` is called with this input
    Then 1 diagnostic should be reported
    And the diagnostic error message should contain "Invalid JSON keyword"
    And a non-nil Expression object should be returned

  Scenario: Parsing JSON expression with Start Position for correct range mapping
    Given a full JSON source string containing an attribute:
      """
      {
        "foo": "bar"
      }
      """
    And a partial JSON string representing the attribute's value: `"bar"`
    And the start position of the partial string value within the full string is Line 2, Column 10
    When the full JSON source is parsed using `json.Parse` to get the expression for "foo"
    And the partial JSON string is parsed using `json.ParseExpressionWithStartPos` with the calculated start position
    Then no parse diagnostics should be reported for either parsing operation
    And the source range of the "foo" attribute's expression from the full parse
    Should be equal to the source range of the expression parsed from the partial string
