# Covers tests in ./hclsyntax/variables_test.go
# Specifically, TestVariables

Feature: HCL Syntax - Expression Variable Extraction
  This feature tests the `Variables` function, which identifies all unique
  variable traversals referenced within a given HCL expression AST.

  Scenario Outline: Extracting variables from different HCL expressions
    Given an HCL expression constructed as: <expression_description>
    When the `Variables` function is called with this expression
    Then the returned list of `hcl.Traversal` objects should be <expected_traversals_list_repr>

    Examples:
      | expression_description                                                                 | expected_traversals_list_repr                                     |
      | LiteralValueExpr(cty.True)                                                             | `[]`                                                              |
      | ScopeTraversalExpr("foo")                                                              | `[Traversal("foo")]`                                              |
      | BinaryOpExpr(ScopeTraversalExpr("foo"), OpAdd, ScopeTraversalExpr("bar"))              | `[Traversal("foo"), Traversal("bar")]`                            |
      | UnaryOpExpr(OpNegate, ScopeTraversalExpr("foo"))                                         | `[Traversal("foo")]`                                              |
      | ConditionalExpr(Cond:ST("foo"), True:ST("bar"), False:ST("baz"))                        | `[Traversal("foo"), Traversal("bar"), Traversal("baz")]`            |
      | ForExpr(k,v in ST("foo"): KeyExpr(ST("k")+ST("bar")) ValExpr(ST("v")+ST("baz")) If(ST("k")<ST("limit"))) | `[Traversal("foo"), Traversal("bar"), Traversal("baz"), Traversal("limit")]` | # Note: k,v are local vars
      | ScopeTraversalExpr("data.null_data_source.multi[0]")                                   | `[Traversal("data.null_data_source.multi[0]")]`                   |
      | RelativeTraversalExpr(Source:FuncCall("sort",Args:[ST("data.null_data_source.multi")]), Traversal:[Index(0)]) | `[Traversal("data.null_data_source.multi")]`                    |

    # Notes on representation:
    # - ST("name") is shorthand for ScopeTraversalExpr("name").
    # - Traversal("foo") represents hcl.Traversal{hcl.TraverseRoot{Name:"foo"}}.
    # - Traversal("data.null_data_source.multi[0]") represents a multi-step traversal.
    # - For ForExpr, "k" and "v" are local iteration variables and should not appear in the output.
    # - FuncCall("name", Args:[...]) represents a FunctionCallExpr.
    # - Index(0) represents hcl.TraverseIndex{Key: cty.NumberFloatVal(0)} or cty.NumberIntVal(0). The Go test uses FloatVal for the combined case.
