# Covers types and functions in ./traversal.go

Feature: HCL Traversal Operations
  This feature tests the creation, manipulation, and application of HCL Traversal objects,
  which represent a sequence of steps to navigate through HCL values or scopes.

  Scenario Outline: Determining if a Traversal is Relative
    Given a Traversal defined by the steps: <steps_description>
    When `IsRelative()` is called on the Traversal
    Then the result should be <is_relative_expected>

    Examples:
      | steps_description                 | is_relative_expected |
      | (empty traversal)                 | true                 |
      | TraverseRoot("var")               | false                | # Absolute
      | TraverseAttr("attr")              | true                 | # Relative
      | TraverseRoot("var"), TAttr("a")   | false                | # Absolute
      | TAttr("a"), TIndex(0)             | true                 | # Relative

  Scenario: Applying a Relative Traversal successfully
    Given a cty.Value `Object({"outer": ListVal([StringVal("first"), StringVal("target")])})`
    And a relative Traversal: TraverseAttr("outer"), TraverseIndex(1)
    When `TraverseRel` is called on the Traversal with the cty.Value
    Then the result should be StringVal("target")
    And no diagnostics should be reported

  Scenario: Applying a Relative Traversal with an intermediate error
    Given a cty.Value `Object({"outer": StringVal("not_a_list")})`
    And a relative Traversal: TraverseAttr("outer"), TraverseIndex(0)
    When `TraverseRel` is called on the Traversal with the cty.Value
    Then diagnostics should be reported (e.g., "Invalid index: This value does not have any indices.")
    And the result should be cty.DynamicVal

  Scenario: Attempting to apply an Absolute Traversal with TraverseRel
    Given an absolute Traversal: TraverseRoot("var")
    And a cty.Value StringVal("any")
    When `TraverseRel` is called on the Traversal with the cty.Value
    Then the operation should panic with message "can't use TraverseRel on an absolute traversal"

  Scenario Outline: Applying an Absolute Traversal with TraverseAbs
    Given an EvalContext with variables: <variables_json>
    And an absolute Traversal: <traversal_description>
    When `TraverseAbs` is called on the Traversal with the EvalContext
    Then the resulting cty.Value should be <expected_value_string>
    And the number of diagnostics should be <diagnostics_count>
    And if diagnostics are reported, the first summary should contain "<first_diagnostic_summary_contains>"

    Examples:
      | variables_json                                | traversal_description              | expected_value_string | diagnostics_count | first_diagnostic_summary_contains |
      | `{"var": "hello"}`                            | TraverseRoot("var")                | StringVal("hello")    | 0                 |                                   |
      | `{"root": {"attr": 123}}`                     | TraverseRoot("root"), TAttr("attr")| NumberIntVal(123)     | 0                 |                                   |
      | `{"p": {"var": "found"}}` (var in parent)     | TraverseRoot("var")                | StringVal("found")    | 0                 |                                   | # EvalContext has parent with "var"
      | `{}`                                          | TraverseRoot("missing")            | DynamicVal            | 1                 | "Unknown variable"                |
      | `{"miss":"val"}` (for suggestion)             | TraverseRoot("missing")            | DynamicVal            | 1                 | "Unknown variable"                | # "Did you mean \"miss\"?"
      | `(nil variables map)`                         | TraverseRoot("var")                | DynamicVal            | 1                 | "Variables not allowed"           |

  Scenario: Attempting to apply a Relative Traversal with TraverseAbs
    Given a relative Traversal: TraverseAttr("attr")
    And an EvalContext
    When `TraverseAbs` is called on the Traversal with the EvalContext
    Then the operation should panic with message "can't use TraverseAbs on a relative traversal"

  Scenario: Splitting an Absolute Traversal with SimpleSplit
    Given an absolute Traversal: TraverseRoot("a"), TraverseAttr("b"), TraverseIndex(0)
    When `SimpleSplit()` is called on the Traversal
    Then the `Abs` part of the TraversalSplit should be TraverseRoot("a")
    And the `Rel` part should be TraverseAttr("b"), TraverseIndex(0)

  Scenario: Attempting SimpleSplit on a Relative Traversal
    Given a relative Traversal: TraverseAttr("a")
    When `SimpleSplit()` is called on the Traversal
    Then the operation should panic with message "can't use SimpleSplit on a relative traversal"

  Scenario: Getting RootName from an Absolute Traversal
    Given an absolute Traversal: TraverseRoot("myRootVar"), TraverseAttr("attr")
    When `RootName()` is called on the Traversal
    Then the result should be "myRootVar"

  Scenario: Attempting RootName on a Relative Traversal
    Given a relative Traversal: TraverseAttr("attr")
    When `RootName()` is called on the Traversal
    Then the operation should panic with message "can't use RootName on a relative traversal"

  Scenario: Getting SourceRange from a Traversal
    Given a Traversal: TraverseRoot("a" Range1), TraverseAttr("b" Range2), TraverseIndex(0 Range3)
      # Range1, Range2, Range3 are distinct hcl.Range objects
    When `SourceRange()` is called on the Traversal
    Then the resulting hcl.Range should span from the start of Range1 to the end of Range3

  Scenario: Getting SourceRange from an empty Traversal
    Given an empty Traversal
    When `SourceRange()` is called
    Then the resulting hcl.Range should be an empty range (all zero values)

  Scenario: Joining Traversals with TraversalJoin
    Given an absolute Traversal "absT": TraverseRoot("a")
    And a relative Traversal "relT": TraverseAttr("b"), TraverseIndex(0)
    When `TraversalJoin(absT, relT)` is called
    Then the resulting Traversal should be: TraverseRoot("a"), TraverseAttr("b"), TraverseIndex(0)

  Scenario Outline: Invalid TraversalJoin attempts
    Given an absolute Traversal "absT": TraverseRoot("a")
    And a relative Traversal "relT": TraverseAttr("b")
    When `TraversalJoin` is called with <first_arg> and <second_arg>
    Then the operation should panic with message "<expected_panic_message>"

    Examples:
      | first_arg | second_arg | expected_panic_message                               |
      | relT      | relT       | "first argument to TraversalJoin must be absolute"   |
      | absT      | absT       | "second argument to TraversalJoin must be relative"  |

  Scenario: Using TraversalSplit to traverse
    Given an EvalContext with variable "config" = ObjectVal({"setting": StringVal("active")})
    And a TraversalSplit with Abs = TraverseRoot("config") and Rel = TraverseAttr("setting")
    When `Traverse()` is called on the TraversalSplit with the EvalContext
    Then the result should be StringVal("active")
    And no diagnostics should be reported

  Scenario: TraverseSplat step behavior
    Given a cty.Value ListVal([StringVal("a"), StringVal("b")])
    And a TraverseSplat traverser
    When `TraversalStep` is called on the TraverseSplat with the cty.Value
    Then the operation should panic with message "TraverseSplat not yet implemented"

    # Notes for tables:
    # - Traversal descriptions like `TraverseRoot("var"), TAttr("a")` are simplified representations.
    # - `TAttr("a")` means `TraverseAttr{Name:"a"}`. `TIndex(0)` means `TraverseIndex{Key:cty.NumberIntVal(0)}`.
    # - `variables_json` for EvalContext: e.g., `{"var": "hello"}` means map[string]cty.Value{"var": cty.StringVal("hello")}.
    #   `(nil variables map)` means EvalContext.Variables is nil.
    #   `{"p": {"var": "found"}}` implies a parent context setup.
    # - `expected_value_string` is a cty.Value string representation.
    # - Ranges like `Range1` are placeholders for distinct hcl.Range objects.
    # - An "empty range" has all zero values for its fields.
