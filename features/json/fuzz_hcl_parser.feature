# This BDD feature file corresponds to the Go fuzz test file:
# ./json/fuzz_test.go
#
# It covers the following Go fuzz tests:
# - FuzzParse (for full JSON documents)
# - FuzzExpression (for JSON expressions)

Feature: HCL JSON Parser Fuzzing
  This feature describes the properties being tested by fuzzing the HCL JSON
  parser (`json.Parse`) and the JSON expression parser/evaluator (`json.ParseExpression`, `expr.Value`).
  The primary goal of these fuzz tests is to ensure that the parsing and evaluation
  logic does not panic when encountering arbitrary or malformed inputs.

  Background:
    Given the HCL JSON parsing context

  Scenario: Fuzzing json.Parse for full JSON documents
    This scenario captures the property tested by `FuzzParse`.
    The fuzzer generates various byte inputs to simulate potentially malformed or
    unexpected JSON document structures.

    Given an arbitrary byte stream as input for a JSON HCL document
    When `json.Parse` attempts to parse this input
    Then the `json.Parse` function should not panic, regardless of input validity
    And any diagnostics returned are secondary to the no-panic requirement for this fuzz test

  Scenario: Fuzzing json.ParseExpression and subsequent Value evaluation
    This scenario captures the properties tested by `FuzzExpression`.
    The fuzzer generates various byte inputs to simulate potentially malformed or
    unexpected JSON HCL expressions.

    Given an arbitrary byte stream as input for a JSON HCL expression
    When `json.ParseExpression` attempts to parse this input
    Then the `json.ParseExpression` function should not panic, regardless of input validity
    And if an expression is successfully parsed from the input
    When the `Value(nil)` method is called on the parsed expression
    Then the `Value(nil)` method should not panic
    And any diagnostics returned from parsing or evaluation are secondary to the no-panic requirement for this fuzz test
```
