# Covers functions in ./expr_unwrap.go

Feature: HCL Expression Unwrapping
  This feature tests the `UnwrapExpression` and `UnwrapExpressionUntil` functions,
  which are used to retrieve underlying physical expressions that might be
  encapsulated by one or more wrapper expressions.

  Background:
    Given different types of HCL Expressions:
      - "PhysicalExprA": A base expression that does not implement `unwrapExpression`.
      - "WrapperB": An expression that implements `unwrapExpression` and wraps another expression. It can be configured to return its inner expression or nil.
      - "WrapperC": Similar to WrapperB, can wrap another expression.
    And an `until` callback function that can be configured to return true for specific expression types or instances.

  Scenario: UnwrapExpression fully unwraps multiple layers
    Given an expression chain: WrapperC -> WrapperB -> PhysicalExprA, where each wrapper returns its inner expression
    When `UnwrapExpression` is called with WrapperC
    Then the result should be PhysicalExprA

  Scenario: UnwrapExpression on a non-wrapper expression
    Given PhysicalExprA
    When `UnwrapExpression` is called with PhysicalExprA
    Then the result should be PhysicalExprA

  Scenario: UnwrapExpression stops if a wrapper's UnwrapExpression method returns nil
    Given an expression chain: WrapperC -> WrapperB -> PhysicalExprA
    And WrapperB's `UnwrapExpression` method is configured to return nil
    When `UnwrapExpression` is called with WrapperC
    Then the result should be WrapperB

  Scenario: UnwrapExpressionUntil stops at the first wrapper satisfying the condition
    Given an expression chain: WrapperC -> WrapperB -> PhysicalExprA, where each wrapper returns its inner expression
    And the `until` callback is configured to return true for WrapperB, and false otherwise
    When `UnwrapExpressionUntil` is called with WrapperC and the `until` callback
    Then the result should be WrapperB

  Scenario: UnwrapExpressionUntil reaches the physical expression if no wrapper satisfies the condition
    Given an expression chain: WrapperC -> WrapperB -> PhysicalExprA, where each wrapper returns its inner expression
    And the `until` callback is configured to return true only for PhysicalExprA, and false otherwise
    When `UnwrapExpressionUntil` is called with WrapperC and the `until` callback
    Then the result should be PhysicalExprA

  Scenario: UnwrapExpressionUntil returns nil if the condition is never met (even for physical expr)
    Given an expression chain: WrapperC -> WrapperB -> PhysicalExprA, where each wrapper returns its inner expression
    And the `until` callback is configured to always return false
    When `UnwrapExpressionUntil` is called with WrapperC and the `until` callback
    Then the result should be nil

  Scenario: UnwrapExpressionUntil on a non-wrapper expression that satisfies the condition
    Given PhysicalExprA
    And the `until` callback is configured to return true for PhysicalExprA
    When `UnwrapExpressionUntil` is called with PhysicalExprA and the `until` callback
    Then the result should be PhysicalExprA

  Scenario: UnwrapExpressionUntil on a non-wrapper expression that does not satisfy the condition
    Given PhysicalExprA
    And the `until` callback is configured to return false for PhysicalExprA
    When `UnwrapExpressionUntil` is called with PhysicalExprA and the `until` callback
    Then the result should be nil

  Scenario: UnwrapExpressionUntil stops and returns nil if a wrapper dynamically prevents unwrap before condition is met
    Given an expression chain: WrapperC -> WrapperB -> PhysicalExprA
    And WrapperB's `UnwrapExpression` method is configured to return nil
    And the `until` callback is configured to return false for WrapperC and WrapperB, but true for PhysicalExprA
    When `UnwrapExpressionUntil` is called with WrapperC and the `until` callback
    Then the result should be nil (stops at WrapperB, for which `until` is false)
