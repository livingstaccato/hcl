# Covers tests in ./ext/typeexpr/type_type_test.go
# Specifically, TestTypeConstraintType and TestConvertFunc

Feature: Type Constraint Values and Convert Function
  This feature tests the creation and usage of `TypeConstraint` cty.Value capsules,
  which represent cty.Type values, and the `ConvertFunc` that uses these
  capsules to perform type conversions.

  Scenario: TypeConstraintVal creation and equality
    Given a TypeConstraintVal `tyVal1` created from `cty.String`
    And a TypeConstraintVal `tyVal2` created from `cty.String`
    And a TypeConstraintVal `tyVal3` created from `cty.Number`
    Then `tyVal1` should be equal to `tyVal2`
    And `tyVal1` should not be equal to `tyVal3`
    And extracting the cty.Type from `tyVal1` should yield `cty.String`
    And extracting the cty.Type from `tyVal3` should yield `cty.Number`

  Scenario Outline: Calling ConvertFunc with various inputs
    Given a cty.Value `<input_value_cty>`
    And a TypeConstraintVal `<target_type_cty_val>` representing cty.Type `<target_type_cty>`
    When ConvertFunc is called with `<input_value_cty>` and `<target_type_cty_val>`
    Then the resulting cty.Value should be `<expected_value_cty>`
    And if an error is expected, its message should contain "<expected_error_message>"
    And if no error is expected, no error should occur

    Examples:
      | input_value_cty                | target_type_cty_val         | target_type_cty | expected_value_cty           | expected_error_message |
      | StringVal("hello")             | TypeConstraintVal(String)   | String          | StringVal("hello")           |                        |
      | True                           | TypeConstraintVal(String)   | String          | StringVal("true")            |                        |
      | StringVal("hello")             | TypeConstraintVal(Bool)     | Bool            | NilVal                       | "a bool is required"   |
      | UnknownVal(Bool)               | TypeConstraintVal(Bool)     | Bool            | UnknownVal(Bool)             |                        |
      | DynamicVal                     | TypeConstraintVal(Bool)     | Bool            | UnknownVal(Bool)             |                        |
      | NullVal(Bool)                  | TypeConstraintVal(Bool)     | Bool            | NullVal(Bool)                |                        |
      | NullVal(DynamicPseudoType)     | TypeConstraintVal(Bool)     | Bool            | NullVal(Bool)                |                        |
      | StringVal("hello").Mark(1)     | TypeConstraintVal(String)   | String          | StringVal("hello").Mark(1)   |                        |

    # Notes:
    # - cty types like String, Bool, Number are shorthand for cty.String, cty.Bool, etc.
    # - TypeConstraintVal(Type) means creating a type constraint value from the given cty.Type.
    # - Values like StringVal("hello") are cty.Value representations.
    # - NilVal implies cty.NilVal.
    # - UnknownVal(Type) means cty.UnknownVal(cty.Type).
    # - DynamicVal means cty.DynamicVal.
    # - Marks like .Mark(1) are cty value marks.
