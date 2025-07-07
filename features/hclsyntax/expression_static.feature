# Covers tests in ./hclsyntax/expression_static_test.go
# Specifically, TestTraversalStatic, TestTupleStatic, and TestMapStatic

Feature: HCL Syntax - Static Expression Analysis
  This feature tests the static analysis of HCL expressions, specifically
  extracting traversals, list elements, and map key-value pairs from
  parsed expression ASTs without full evaluation against an EvalContext
  (though literal values are resolved).

  Scenario: Statically analyzing a scope traversal expression
    Given an HCL expression string "a.b.c"
    When the expression is parsed
    And `hcl.AbsTraversalForExpr` is called on the parsed expression
    Then no parse or traversal extraction diagnostics should be reported
    And the resulting traversal should consist of the following steps:
      | Step | Type         | Name | SourceRange       |
      | 1    | TraverseRoot | a    | L1C1B0-L1C2B1     |
      | 2    | TraverseAttr | b    | L1C2B1-L1C4B3     |
      | 3    | TraverseAttr | c    | L1C4B3-L1C6B5     |

  Scenario: Statically analyzing a tuple constructor expression
    Given an HCL expression string "[true, false]"
    When the expression is parsed
    And `hcl.ExprList` is called on the parsed expression
    Then no parse or list extraction diagnostics should be reported
    And the resulting list of expressions should have 2 elements
    And evaluating the first element expression (with nil context) should yield cty.True
    And evaluating the second element expression (with nil context) should yield cty.False
    And no evaluation diagnostics should be reported for these elements

  Scenario: Statically analyzing an object constructor expression
    Given an HCL expression string `{"foo":true,"bar":false}`
    When the expression is parsed
    And `hcl.ExprMap` is called on the parsed expression
    Then no parse or map extraction diagnostics should be reported
    And the resulting list of key-value pair expressions should have 2 items
    And evaluating these key-value pairs (with nil context) should yield a map:
      | Key          | Value   |
      | StringVal("foo") | True    |
      | StringVal("bar") | False   |
    And no evaluation diagnostics should be reported for these keys or values

    # Notes for tables:
    # - SourceRange format: L1C1B0-L1C2B1 means Line 1, Col 1, Byte 0 to Line 1, Col 2, Byte 1.
    # - cty.Value representations: True, False, StringVal("foo").
