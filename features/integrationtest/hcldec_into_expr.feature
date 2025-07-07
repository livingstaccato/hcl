# Covers tests in ./integrationtest/hcldec_into_expr_test.go
# Specifically, TestHCLDecDecodeToExpr

Feature: HCLDec Decoding to Custom Expression Types
  This feature tests the capability of `hcldec` to decode HCL attributes
  into special expression-capturing types from the `ext/customdecode` package,
  namely `customdecode.ExpressionType` and `customdecode.ExpressionClosureType`.
  This allows for deferred expression evaluation or evaluation in modified contexts.

  Scenario: Decoding attributes into Expression, ExpressionClosure, and standard cty.String
    Given an HCL input:
      """
      a = foo
      b = foo
      c = "hello"
      """
    And an `hcldec.ObjectSpec` defining attributes:
      | Name | HCLDec Type                 | Required |
      | a    | customdecode.ExpressionType   | true     |
      | b    | customdecode.ExpressionClosureType | true     |
      | c    | cty.String                  | true     |
    And an initial `hcl.EvalContext` with variable "foo" set to StringVal "foo value"
    When the HCL input is parsed and decoded using the spec and context
    Then no parsing or decoding diagnostics should be reported
    And the decoded attribute "a" should have type `customdecode.ExpressionType`
    And the HCL expression extracted from attribute "a" using `customdecode.ExpressionFromVal` should be a scope traversal for "foo" with source range L2C5-L2C8
    And the decoded attribute "b" should have type `customdecode.ExpressionClosureType`
    And the `customdecode.ExpressionClosure` extracted from attribute "b" when its `Value()` method is called (using its captured context) should result in StringVal "foo value"
    And no evaluation diagnostics should be reported for evaluating the closure "b"
    And the decoded attribute "c" should have type `cty.String` and value StringVal "hello"

  Scenario: Evaluating an ExpressionClosure's underlying Expression with a derived EvalContext
    Given an HCL input:
      """
      b = foo
      """
    And an `hcldec.ObjectSpec` defining attribute "b" with HCLDec Type `customdecode.ExpressionClosureType` (required true)
    And an initial `hcl.EvalContext` with variable "foo" set to StringVal "original foo value"
    When the HCL input is parsed and decoded to obtain an `ExpressionClosure` for attribute "b"
    And a new child `hcl.EvalContext` is derived from the closure's captured context
    And in this derived context, the variable "foo" is set to StringVal "overridden foo value"
    When the closure's underlying `Expression` (not the closure itself) is evaluated using this derived context
    Then the resulting cty.Value should be StringVal "overridden foo value"
    And no evaluation diagnostics should be reported for this specific evaluation

    # Notes for tables and steps:
    # - `customdecode.ExpressionType` and `customdecode.ExpressionClosureType` refer to the actual Go types.
    # - `cty.String` refers to the cty.Type.
    # - `StringVal "value"` refers to `cty.StringVal("value")`.
    # - Source ranges like L2C5-L2C8 are simplified representations of hcl.Range.
