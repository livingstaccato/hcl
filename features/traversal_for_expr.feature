# Covers tests in ./traversal_for_expr_test.go
# Specifically, TestAbsTraversalForExpr, TestRelTraversalForExpr, and TestExprAsKeyword

Feature: Expression Traversal
  This feature covers how expressions are traversed and interpreted in HCL.

  Scenario: Absolute Traversal for Expression - Supported
    Given an expression that supports traversal with root name "foo"
    When the absolute traversal for the expression is retrieved
    Then the traversal should have one step
    And the first step should be a TraverseRoot
    And the root name should be "foo"

  Scenario: Absolute Traversal for Expression - Not Supported
    Given an expression that does not support traversal
    When the absolute traversal for the expression is retrieved
    Then the traversal should be nil
    And error diagnostics should be present

  Scenario: Absolute Traversal for Expression - Declined
    Given an expression that declines traversal
    When the absolute traversal for the expression is retrieved
    Then the traversal should be nil
    And error diagnostics should be present

  Scenario: Absolute Traversal for Expression - Wrapped Delegated
    Given a wrapped expression where the original expression supports traversal with root name "foo"
    When the absolute traversal for the expression is retrieved
    Then the traversal should have one step
    And the first step should be a TraverseRoot
    And the root name should be "foo"

  Scenario: Absolute Traversal for Expression - Doubly Wrapped Delegated
    Given a doubly wrapped expression where the original expression supports traversal with root name "foo"
    When the absolute traversal for the expression is retrieved
    Then the traversal should have one step
    And the first step should be a TraverseRoot
    And the root name should be "foo"

  Scenario: Relative Traversal for Expression - Supported
    Given an expression that supports traversal with root name "foo"
    When the relative traversal for the expression is retrieved
    Then the traversal should have one step
    And the first step should be a TraverseAttr
    And the attribute name should be "foo"

  Scenario: Relative Traversal for Expression - Not Supported
    Given an expression that does not support traversal
    When the relative traversal for the expression is retrieved
    Then the traversal should be nil
    And error diagnostics should be present

  Scenario: Relative Traversal for Expression - Declined
    Given an expression that declines traversal
    When the relative traversal for the expression is retrieved
    Then the traversal should be nil
    And error diagnostics should be present

  Scenario: Expression as Keyword - Supported Root
    Given an expression that supports traversal with root name "foo"
    When the expression is treated as a keyword
    Then the result should be "foo"

  Scenario: Expression as Keyword - Supported Attribute
    Given an expression that supports traversal with root name "foo" and attribute name "bar"
    When the expression is treated as a keyword
    Then the result should be ""

  Scenario: Expression as Keyword - Not Supported
    Given an expression that does not support traversal
    When the expression is treated as a keyword
    Then the result should be ""

  Scenario: Expression as Keyword - Declined
    Given an expression that declines traversal
    When the expression is treated as a keyword
    Then the result should be ""

  Scenario: Expression as Keyword - Wrapped Delegated
    Given a wrapped expression where the original expression supports traversal with root name "foo"
    When the expression is treated as a keyword
    Then the result should be "foo"

  Scenario: Expression as Keyword - Doubly Wrapped Delegated
    Given a doubly wrapped expression where the original expression supports traversal with root name "foo"
    When the expression is treated as a keyword
    Then the result should be "foo"
