# Covers functions in ./traversal_for_expr.go
# Based on test cases in ./traversal_for_expr_test.go
# Specifically, TestAbsTraversalForExpr, TestRelTraversalForExpr, and TestExprAsKeyword

Feature: HCL Expression to Traversal or Keyword Conversion
  This feature tests the ability to interpret HCL expressions as static traversals
  (absolute or relative) or as simple keywords, without full evaluation. This is
  useful for configuration elements that expect references or specific identifiers.

  Background:
    Given mock HCL expressions that can:
      1. Support traversal, returning a specific `hcl.Traversal` (e.g., `TraverseRoot{Name:"foo"}` or `TraverseRoot{Name:"foo"}, TraverseAttr{Name:"bar"}`).
      2. Not support traversal (does not implement `AsTraversal` interface effectively).
      3. Decline traversal (implements `AsTraversal` but returns `nil`).
      4. Wrap another expression, delegating traversal behavior via `UnwrapExpression`.

  Scenario Outline: Converting an Expression to an Absolute Traversal
    Given an HCL expression that is <expression_type>
    And if it supports traversal, its root name is "<root_name>"
    When `AbsTraversalForExpr` is called with the expression
    Then if a traversal is expected (<expect_traversal>):
      And the returned traversal should not be nil
      And no diagnostics should be reported
      And the traversal should have 1 step(s)
      And the first step should be a TraverseRoot with name "<root_name>"
    And if a traversal is NOT expected (<expect_traversal> is false):
      And the returned traversal should be nil
      And diagnostics should be reported indicating an invalid expression for traversal

    Examples:
      | expression_type                                  | root_name | expect_traversal |
      | supported (simple root)                          | "foo"     | true             |
      | not supported                                    |           | false            |
      | declined                                         |           | false            |
      | wrapped (delegates to supported simple root)     | "foo"     | true             |
      | doubly wrapped (delegates to supported simple root)| "foo"     | true             |

  Scenario Outline: Converting an Expression to a Relative Traversal
    Given an HCL expression that is <expression_type>
    And if it supports traversal, its root name is "<root_name_as_first_attr>"
    When `RelTraversalForExpr` is called with the expression
    Then if a traversal is expected (<expect_traversal>):
      And the returned traversal should not be nil
      And no diagnostics should be reported
      And the traversal should have 1 step(s)
      And the first step should be a TraverseAttr with name "<root_name_as_first_attr>"
    And if a traversal is NOT expected (<expect_traversal> is false):
      And the returned traversal should be nil
      And diagnostics should be reported indicating an invalid expression for traversal

    Examples:
      | expression_type         | root_name_as_first_attr | expect_traversal |
      | supported (simple root) | "foo"                   | true             |
      | not supported           |                         | false            |
      | declined                |                         | false            |

  Scenario Outline: Converting an Expression to a Keyword
    Given an HCL expression that is <expression_type>
    And if it supports traversal, its root name is "<root_name>" and attribute name is "<attr_name>" (if any)
    When `ExprAsKeyword` is called with the expression
    Then the resulting string should be "<expected_keyword>"

    Examples:
      | expression_type                                  | root_name | attr_name | expected_keyword |
      | supported (simple root)                          | "foo"     |           | "foo"            |
      | supported (root and attribute)                   | "foo"     | "bar"     | ""               | # Not a single keyword
      | not supported                                    |           |           | ""               |
      | declined                                         |           |           | ""               |
      | wrapped (delegates to supported simple root)     | "foo"     |           | "foo"            |
      | doubly wrapped (delegates to supported simple root)| "foo"     |           | "foo"            |
