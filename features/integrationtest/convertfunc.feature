# Covers integration test in ./integrationtest/convertfunc_test.go
# Related to function typeexpr.ConvertFunc from ./ext/typeexpr/type_type.go

Feature: HCL Integration of Type Conversion Function
  This feature tests the correct functioning of the `typeexpr.ConvertFunc`
  when invoked from within an HCL native syntax expression. It specifically
  verifies that the second argument to `convert` (the type constraint)
  is correctly parsed as a type expression due to the `customdecode` mechanism.

  Scenario: Using the 'convert' function in an HCL expression to change a tuple to a list of strings
    Given the HCL expression string: `convert(["hello"], list(string))`
      # This expression aims to convert a cty.Tuple containing one string
      # into a cty.List of strings.
    And an evaluation context that includes `typeexpr.ConvertFunc` registered as "convert"
    When the HCL expression string is parsed using `hclsyntax.ParseExpression`
    Then no parsing diagnostics should be reported
    And the parsed expression should be valid
    When the parsed HCL expression is evaluated with the context
    Then no evaluation diagnostics should be reported
    And the resulting cty.Value should be a List of String with one element "hello"
    And the type of the resulting cty.Value should be `list(string)`

  Scenario: Using the 'convert' function in an HCL expression to change a number to a string
    Given the HCL expression string: `convert(123, string)`
    And an evaluation context that includes `typeexpr.ConvertFunc` registered as "convert"
    When the HCL expression string is parsed using `hclsyntax.ParseExpression`
    Then no parsing diagnostics should be reported
    And the parsed expression should be valid
    When the parsed HCL expression is evaluated with the context
    Then no evaluation diagnostics should be reported
    And the resulting cty.Value should be StringVal "123"
    And the type of the resulting cty.Value should be `string`

  Scenario: Using the 'convert' function in an HCL expression with a failing conversion
    Given the HCL expression string: `convert("not-a-bool", bool)`
      # Attempting to convert a non-boolean string to a boolean.
    And an evaluation context that includes `typeexpr.ConvertFunc` registered as "convert"
    When the HCL expression string is parsed using `hclsyntax.ParseExpression`
    Then no parsing diagnostics should be reported
    And the parsed expression should be valid
    When the parsed HCL expression is evaluated with the context
    Then diagnostics should be reported
    And the first diagnostic summary should be "Invalid argument value"
    And the first diagnostic detail should contain "a bool is required"
    And the resulting cty.Value should be cty.NilVal (or DynamicVal depending on error handling specifics)

    # Note: The key aspect tested here is the successful parsing and delegation of the
    # type expression (e.g., `list(string)`, `string`, `bool`) to TypeConstraintType's
    # custom decoder, allowing ConvertFunc to receive a cty.Type as its second argument.
    # The underlying conversion logic of cty.Convert is tested more exhaustively
    # in features/ext/typeexpr/type_type.feature.
