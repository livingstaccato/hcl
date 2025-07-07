# This BDD feature file corresponds to the Go test file:
# ./json/number_test.go
#
# It covers the ParseJSONNumber function for parsing JSON number strings
# into cty.Number values, including handling of different formats and error cases.

Feature: HCL JSON Number Parsing
  This feature describes the behavior of `json.ParseJSONNumber` when converting
  JSON number strings into `cty.Value` representations, paying attention to
  the underlying Go type used (int, float64, or big.Float) for precision.

  Background:
    Given the HCL JSON parsing context

  Scenario Outline: Parsing valid JSON number strings
    Given the JSON number string representation: "<number_string>"
    When the string is parsed using `json.ParseJSONNumber`
    Then the resulting cty.Value should be numerically equivalent to <expected_value_repr>
    And its internal representation should be <expected_cty_raw_type>
    And no diagnostics should be reported

    Examples:
      | number_string             | expected_value_repr             | expected_cty_raw_type |
      | `0`                       | `0`                             | `cty.NumberIntVal`    |
      | `1`                       | `1`                             | `cty.NumberIntVal`    |
      | `-1`                      | `-1`                            | `cty.NumberIntVal`    |
      | `1.5`                     | `1.5`                           | `cty.NumberFloatVal`  |
      | `1e2`                     | `100`                           | `cty.NumberFloatVal`  |
      | `1E2`                     | `100`                           | `cty.NumberFloatVal`  |
      | `1.5e2`                   | `150`                           | `cty.NumberFloatVal`  |
      | `1.5E2`                   | `150`                           | `cty.NumberFloatVal`  |
      | `1e-2`                    | `0.01`                          | `cty.NumberFloatVal`  |
      | `1E-2`                    | `0.01`                          | `cty.NumberFloatVal`  |
      | `1.5e-2`                  | `0.015`                         | `cty.NumberFloatVal`  |
      | `1.5E-2`                  | `0.015`                         | `cty.NumberFloatVal`  |
      | `9223372036854775807`     | `9223372036854775807`           | `cty.NumberIntVal`    | # maxInt
      | `-9223372036854775808`    | `-9223372036854775808`          | `cty.NumberIntVal`    | # minInt
      | `9223372036854775808`     | `9223372036854775808`           | `cty.NumberValBigFloat`| # maxInt + 1
      | `-9223372036854775809`    | `-9223372036854775809`          | `cty.NumberValBigFloat`| # minInt - 1
      | `1.7976931348623157e+308` | `1.7976931348623157e+308`       | `cty.NumberFloatVal`  | # Max float64
      | `5e-324`                  | `5e-324`                        | `cty.NumberFloatVal`  | # Smallest float64
      | `1.7976931348623157e+309` | `1.7976931348623157e+309`       | `cty.NumberValBigFloat`| # Too large for float64
      | `1e-324`                  | `1e-324`                        | `cty.NumberValBigFloat`| # Too small for float64

  Scenario Outline: Parsing invalid JSON number strings
    Given the JSON number string representation: "<invalid_number_string>"
    When the string is parsed using `json.ParseJSONNumber`
    Then the resulting cty.Value should be cty.NilType
    And one diagnostic should be reported with Summary "Invalid number literal"

    Examples:
      | invalid_number_string |
      | `--1`                 |
      | `1-1`                 |
      | `1.`                  |
      | `1.e2`                |
      | `1e`                  |
      | `1e+`                 |
      | `1e+f`                |

    # Notes for table values:
    # - `expected_value_repr`: The numerical value. For large/small numbers, it's the same as input.
    # - `expected_cty_raw_type`: Indicates the expected underlying representation for cty.Number
    #   (e.g., `cty.NumberIntVal` for Go int64, `cty.NumberFloatVal` for Go float64,
    #   `cty.NumberValBigFloat` for `big.Float`). This reflects the Go test's use of RawEquals.
    # - `cty.NilType` is used as the placeholder for the value when parsing fails.
```
