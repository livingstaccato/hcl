# Covers hcl.EvalContext in ./eval_context.go

Feature: HCL Evaluation Context and Scoping
  This feature tests the creation and behavior of `hcl.EvalContext`, particularly
  its support for hierarchical scoping of variables and functions through parent-child relationships.

  Scenario: Creating a Child Evaluation Context
    Given an existing `hcl.EvalContext` named "ParentCtx"
    When `ParentCtx.NewChild()` is called to create "ChildCtx"
    Then "ChildCtx.Parent()" should return "ParentCtx"
    And "ChildCtx.Variables" should be initially nil or empty
    And "ChildCtx.Functions" should be initially nil or empty

  Scenario: Variable Resolution - Variable defined in Child Context shadows Parent
    Given a "ParentCtx" with variable "shadowVar" set to cty.StringVal "from parent"
    And "ChildCtx" is created as a child of "ParentCtx"
    And variable "shadowVar" in "ChildCtx" is set to cty.StringVal "from child"
    When an HCL expression `shadowVar` is evaluated using "ChildCtx"
    Then the result should be cty.StringVal "from child"
    And no diagnostics should be reported

  Scenario: Variable Resolution - Variable resolved from Parent Context
    Given a "ParentCtx" with variable "parentVar" set to cty.NumberIntVal 100
    And "ChildCtx" is created as a child of "ParentCtx"
    And "ChildCtx" does not have a variable named "parentVar"
    When an HCL expression `parentVar` is evaluated using "ChildCtx"
    Then the result should be cty.NumberIntVal 100
    And no diagnostics should be reported

  Scenario: Variable Resolution - Variable not found in Child or Parent Contexts
    Given a "ParentCtx" with no variable named "missingVar"
    And "ChildCtx" is created as a child of "ParentCtx" and also has no "missingVar"
    When an HCL expression `missingVar` is evaluated using "ChildCtx"
    Then a diagnostic should be reported
    And the diagnostic summary should be "Unknown variable"
    And the diagnostic detail should contain "There is no variable named \"missingVar\""
    And the resulting cty.Value should be cty.DynamicVal

  Scenario: Function Resolution - Function defined in Child Context shadows Parent
    Given a "ParentCtx" with function "myFunc" that returns cty.StringVal "parent_func_result"
    And "ChildCtx" is created as a child of "ParentCtx"
    And function "myFunc" in "ChildCtx" is defined to return cty.StringVal "child_func_result"
    When an HCL expression `myFunc()` is evaluated using "ChildCtx"
    Then the result should be cty.StringVal "child_func_result"
    And no diagnostics should be reported

  Scenario: Function Resolution - Function resolved from Parent Context
    Given a "ParentCtx" with function "parentFunc" that returns cty.NumberIntVal 200
    And "ChildCtx" is created as a child of "ParentCtx"
    And "ChildCtx" does not have a function named "parentFunc"
    When an HCL expression `parentFunc()` is evaluated using "ChildCtx"
    Then the result should be cty.NumberIntVal 200
    And no diagnostics should be reported

  Scenario: Function Resolution - Function not found in Child or Parent Contexts
    Given a "ParentCtx" with no function named "missingFunc"
    And "ChildCtx" is created as a child of "ParentCtx" and also has no "missingFunc"
    When an HCL expression `missingFunc()` is evaluated using "ChildCtx"
    Then a diagnostic should be reported
    And the diagnostic summary should be "Unknown function"
    And the diagnostic detail should contain "There is no function named \"missingFunc\""
    And the resulting cty.Value should be cty.DynamicVal

  Scenario: Variable Resolution - Nil Variables map in a context
    Given a "ParentCtx" with variable "x" = StringVal("parent_x")
    And "ChildCtx" is created as a child of "ParentCtx"
    And "ChildCtx.Variables" is explicitly set to nil
    And "GrandchildCtx" is created as a child of "ChildCtx"
    And variable "y" in "GrandchildCtx" is set to StringVal("grandchild_y")
    When an HCL expression `x` is evaluated using "GrandchildCtx"
    Then the result should be StringVal("parent_x") # Skips ChildCtx's nil map
    When an HCL expression `y` is evaluated using "GrandchildCtx"
    Then the result should be StringVal("grandchild_y")

  Scenario: Accessing Parent when context is root
    Given a root "RootCtx" (created with no parent)
    When `RootCtx.Parent()` is called
    Then the result should be nil

    # Notes:
    # - Mock HCL expressions like `variableName` or `funcName()` are used for simplicity.
    # - The actual lookup logic (checking current context then walking up parents) is part of
    #   the expression evaluation implementation (e.g., in hclsyntax.ScopeTraversalExpr.Value).
    #   These scenarios verify that EvalContext provides the correct structure for this to work.
