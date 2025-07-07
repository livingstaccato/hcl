# Covers tests in ./integrationtest/hcldec_into_expr_test.go
# Specifically, TestHCLDecDecodeToExpr

Feature: HCLDec Decoding to Expression Types
  This feature tests the capability of hcldec to decode HCL attributes
  into special expression-capturing types, specifically `customdecode.ExpressionType`
  and `customdecode.ExpressionClosureType`. This allows deferring expression
  evaluation or evaluating expressions in different contexts.

  Scenario: Decoding attributes into Expression, ExpressionClosure, and standard types
    Given an HCL input:
      """
      a = foo
      b = foo
      c = "hello"
      """
    And an hcldec.ObjectSpec defining:
      | Attribute | Name | Type                        | Required |
      | a         | a    | customdecode.ExpressionType   | true     |
      | b         | b    | customdecode.ExpressionClosureType | true     |
      | c         | c    | cty.String                  | true     |
    And an initial hcl.EvalContext with variable "foo" set to "foo value"
    When the HCL input is parsed and decoded using the spec and context
    Then no parsing or decoding diagnostics should be reported
    And the decoded attribute "a" should have type customdecode.ExpressionType
    And the decoded attribute "b" should have type customdecode.ExpressionClosureType
    And the decoded attribute "c" should have type cty.String
    And the expression extracted from attribute "a" should be a scope traversal for "foo"
      | TraversalRootName | SourceRange        |
      | foo               | L2C5-L2C8 (B5-B8)  |
    And the value of the ExpressionClosure from attribute "b", when evaluated with its captured context, should be "foo value"
    And no evaluation diagnostics should be reported for "b"
    And the value of attribute "c" should be "hello"

  Scenario: Evaluating ExpressionClosure with a derived EvalContext
    Given an HCL input:
      """
      b = foo
      """
    And an hcldec.ObjectSpec defining:
      | Attribute | Name | Type                        | Required |
      | b         | b    | customdecode.ExpressionClosureType | true     |
    And an initial hcl.EvalContext with variable "foo" set to "original foo value"
    When the HCL input is parsed and decoded
    And an ExpressionClosure is obtained from the decoded attribute "b"
    And a new child EvalContext is derived from the closure's captured context
    And in the derived context, variable "foo" is set to "overridden foo value"
    When the closure's underlying expression is evaluated using this derived context
    Then the resulting value should be "overridden foo value"
    And no evaluation diagnostics should be reported
