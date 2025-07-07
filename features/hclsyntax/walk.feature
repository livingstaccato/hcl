# Covers tests in ./hclsyntax/walk_test.go
# Specifically, TestWalk

Feature: HCL Syntax - AST Traversal (Walk)
  This feature tests the `Walk` function, which traverses an HCL expression AST (Abstract Syntax Tree).
  It verifies that the `Enter` and `Exit` methods of a provided `Walker` implementation
  are called in the correct order and with the correct node types for various expressions.

  Scenario Outline: Walking different HCL expression ASTs
    Given an HCL expression string: "<expression_string>"
    When the expression is parsed into an AST node
    And a test walker is used to `Walk` the AST node
    Then no parsing or walking diagnostics should be reported
    And the sequence of (method, node_type) calls recorded by the walker should be:
      | Method    | NodeType                        |
      # The table below will be populated by examples
      <expected_calls>

    Examples:
      | expression_string                   | expected_calls                                                                                                                                                                                                                                                           |
      | `1`                                 | Enter *hclsyntax.LiteralValueExpr<br>Exit *hclsyntax.LiteralValueExpr                                                                                                                                                                                                    |
      | `foo`                               | Enter *hclsyntax.ScopeTraversalExpr<br>Exit *hclsyntax.ScopeTraversalExpr                                                                                                                                                                                              |
      | `1 + 1`                             | Enter *hclsyntax.BinaryOpExpr<br>Enter *hclsyntax.LiteralValueExpr<br>Exit *hclsyntax.LiteralValueExpr<br>Enter *hclsyntax.LiteralValueExpr<br>Exit *hclsyntax.LiteralValueExpr<br>Exit *hclsyntax.BinaryOpExpr                                                     |
      | `(1 + 1)`                           | Enter *hclsyntax.ParenthesesExpr<br>Enter *hclsyntax.BinaryOpExpr<br>Enter *hclsyntax.LiteralValueExpr<br>Exit *hclsyntax.LiteralValueExpr<br>Enter *hclsyntax.LiteralValueExpr<br>Exit *hclsyntax.LiteralValueExpr<br>Exit *hclsyntax.BinaryOpExpr<br>Exit *hclsyntax.ParenthesesExpr |
      | `a[0]`                              | Enter *hclsyntax.ScopeTraversalExpr<br>Exit *hclsyntax.ScopeTraversalExpr                                                                                                                                                                                              | # Index absorbed into traversal
      | `0[foo]`                            | Enter *hclsyntax.IndexExpr<br>Enter *hclsyntax.LiteralValueExpr<br>Exit *hclsyntax.LiteralValueExpr<br>Enter *hclsyntax.ScopeTraversalExpr<br>Exit *hclsyntax.ScopeTraversalExpr<br>Exit *hclsyntax.IndexExpr                                                       |
      | `bar()`                             | Enter *hclsyntax.FunctionCallExpr<br>Exit *hclsyntax.FunctionCallExpr                                                                                                                                                                                                |
      | `bar(1, a)`                         | Enter *hclsyntax.FunctionCallExpr<br>Enter *hclsyntax.LiteralValueExpr<br>Exit *hclsyntax.LiteralValueExpr<br>Enter *hclsyntax.ScopeTraversalExpr<br>Exit *hclsyntax.ScopeTraversalExpr<br>Exit *hclsyntax.FunctionCallExpr                                         |
      | `bar(1, a)[0]`                      | Enter *hclsyntax.RelativeTraversalExpr<br>Enter *hclsyntax.FunctionCallExpr<br>Enter *hclsyntax.LiteralValueExpr<br>Exit *hclsyntax.LiteralValueExpr<br>Enter *hclsyntax.ScopeTraversalExpr<br>Exit *hclsyntax.ScopeTraversalExpr<br>Exit *hclsyntax.FunctionCallExpr<br>Exit *hclsyntax.RelativeTraversalExpr |
      | `[for x in foo: x + 1 if x < 10]`   | Enter *hclsyntax.ForExpr<br>Enter *hclsyntax.ScopeTraversalExpr<br>Exit *hclsyntax.ScopeTraversalExpr<br>Enter hclsyntax.ChildScope<br>Enter *hclsyntax.BinaryOpExpr<br>Enter *hclsyntax.ScopeTraversalExpr<br>Exit *hclsyntax.ScopeTraversalExpr<br>Enter *hclsyntax.LiteralValueExpr<br>Exit *hclsyntax.LiteralValueExpr<br>Exit *hclsyntax.BinaryOpExpr<br>Exit hclsyntax.ChildScope<br>Enter hclsyntax.ChildScope<br>Enter *hclsyntax.BinaryOpExpr<br>Enter *hclsyntax.ScopeTraversalExpr<br>Exit *hclsyntax.ScopeTraversalExpr<br>Enter *hclsyntax.LiteralValueExpr<br>Exit *hclsyntax.LiteralValueExpr<br>Exit *hclsyntax.BinaryOpExpr<br>Exit hclsyntax.ChildScope<br>Exit *hclsyntax.ForExpr |

    # Notes for the expected_calls table:
    # - Each line represents a call to either Enter or Exit method of the walker.
    # - NodeType is the Go type of the AST node being visited.
    # - For 'ForExpr', hclsyntax.ChildScope represents the implicit child scopes for the value and condition expressions.
    # - The <br> tag is used to denote newlines within a single table cell for readability. The actual output would be a list of pairs.
