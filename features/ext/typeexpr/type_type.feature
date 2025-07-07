# Covers functionalities in ./ext/typeexpr/type_type.go
# Based on test cases in ./ext/typeexpr/type_type_test.go

Feature: HCL Type Expressions - Type Constraint Values and Convert Function
  This feature tests the `TypeConstraintType` cty capsule for representing
  `cty.Type` values, and the direct invocation of `typeexpr.ConvertFunc`
  for performing type conversions based on these encapsulated type constraints.

  Scenario: Creation, equality, and extraction of TypeConstraintVal
    Given TypeConstraintVal `tcValStr1` is created from `cty.String`
    And TypeConstraintVal `tcValStr2` is created from `cty.String`
    And TypeConstraintVal `tcValNum` is created from `cty.Number`
    Then `tcValStr1` should be equal to `tcValStr2`
    And `tcValStr1` should not be equal to `tcValNum`
    When `TypeConstraintFromVal` is called with `tcValStr1`
    Then the result should be the cty.Type `cty.String`
    When `TypeConstraintFromVal` is called with `tcValNum`
    Then the result should be the cty.Type `cty.Number`

  Scenario Outline: Calling typeexpr.ConvertFunc directly with cty.Values
    Given an input cty.Value <input_cty_value_repr>
    And a target cty.Type <target_cty_type_repr>
    And a TypeConstraintVal `targetTypeCapVal` is created from <target_cty_type_repr>
    When `typeexpr.ConvertFunc.Call()` is invoked with arguments [<input_cty_value_repr>, `targetTypeCapVal`]
    Then the resulting cty.Value should be <expected_output_cty_value_repr>
    And if an error is expected, its message should contain "<expected_error_message>"
    And if no error is expected, no error should occur

    Examples:
      | input_cty_value_repr           | target_cty_type_repr | expected_output_cty_value_repr   | expected_error_message |
      | `StringVal("hello")`           | `cty.String`         | `StringVal("hello")`             |                        | # String to String
      | `True`                         | `cty.String`         | `StringVal("true")`              |                        | # Bool to String
      | `StringVal("hello")`           | `cty.Bool`           | `NilVal`                         | "a bool is required"   | # String to Bool (invalid)
      | `UnknownVal(cty.Bool)`         | `cty.Bool`           | `UnknownVal(cty.Bool)`           |                        | # Unknown Bool to Bool
      | `DynamicVal`                   | `cty.Bool`           | `UnknownVal(cty.Bool)`           |                        | # Dynamic to Bool
      | `NullVal(cty.Bool)`            | `cty.Bool`           | `NullVal(cty.Bool)`              |                        | # Null Bool to Bool
      | `NullVal(cty.DynamicPseudoType)`| `cty.Bool`           | `NullVal(cty.Bool)`              |                        | # Null Dynamic to Bool
      | `StringVal("hello").Mark(1)`   | `cty.String`         | `StringVal("hello").Mark(1)`     |                        | # String with mark to String

    # Notes for table values:
    # - `cty_value_repr` and `target_cty_type_repr` are string representations of how these cty values/types are constructed in Go tests.
    # - E.g., `StringVal("hello")` means `cty.StringVal("hello")`. `True` means `cty.True`.
    # - `NilVal` implies `cty.NilVal` (likely from `convert.Convert` failure).
    # - `UnknownVal(cty.Type)` means `cty.UnknownVal(the_type)`. `DynamicVal` means `cty.DynamicVal`.
    # - `.Mark(1)` indicates a cty value mark.
    # - The custom decoding behavior of TypeConstraintType when used in HCL expressions is tested separately
    #   in features/integrationtest/convertfunc.feature. This scenario tests direct function calls.
