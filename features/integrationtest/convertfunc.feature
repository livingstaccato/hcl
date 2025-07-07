# Covers tests in ./integrationtest/convertfunc_test.go
# Specifically, TestTypeConvertFunc

Feature: Type Conversion Function Integration
  This feature tests the integration of the `convert` function from `ext/typeexpr`
  within the HCL evaluation process. It specifically verifies that the function
  correctly interprets its second argument as a type expression rather than a
  value expression.

  Scenario: Using the 'convert' function to change a tuple to a list of strings
    Given the HCL expression: `convert(["hello"], list(string))`
    And an evaluation context containing the `typeexpr.ConvertFunc` as "convert"
    When the expression is parsed
    Then no parsing diagnostics should be reported
    When the parsed expression is evaluated with the context
    Then no evaluation diagnostics should be reported
    And the resulting value should be a cty.List of strings containing one element "hello"
    And the resulting value type should be list(string)
