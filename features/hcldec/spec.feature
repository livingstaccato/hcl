# Covers tests in ./hcldec/spec_test.go
# Specifically, TestDefaultSpec, TestValidateFuncSpec, and TestRefineValueSpec

Feature: HCL Decoding Specifications
  This feature covers different HCL decoding specifications and their behaviors.

  Scenario: DefaultSpec - Primary Set
    Given a configuration:
      """
      foo = fooval
      bar = barval
      """
    And a DefaultSpec with "foo" as primary and "bar" as default, both of type string
    And an evaluation context where "fooval" is "foo value" and "barval" is "bar value"
    When the configuration is decoded using the DefaultSpec
    Then the decoded value should be "foo value"
    And the required variables should include "fooval" and "barval"

  Scenario: DefaultSpec - Primary Not Set (Null)
    Given a configuration:
      """
      foo = fooval
      bar = barval
      """
    And a DefaultSpec with "foo" as primary and "bar" as default, both of type string
    And an evaluation context where "fooval" is null (string) and "barval" is "bar value"
    When the configuration is decoded using the DefaultSpec
    Then the decoded value should be "bar value"

  Scenario: ValidateSpec - Validation Function Called (Without Explicit Range)
    Given a configuration:
      """
      foo = "invalid"
      """
    And a ValidateSpec for attribute "foo" of type string
    And a validation function that returns a warning "OK" with detail "validation called correctly" if the value is "invalid"
    When the configuration is decoded using the ValidateSpec
    Then diagnostics should contain 1 warning
    And the warning summary should be "OK"
    And the warning detail should be "validation called correctly"
    And the warning should have a subject range

  Scenario: ValidateSpec - Validation Function Called (With Explicit Range)
    Given a configuration:
      """
      foo = "invalid"
      """
    And a ValidateSpec for attribute "foo" of type string
    And a validation function that returns a warning "OK" with detail "validation called correctly" and subject range "foobar:99,99-999,999" if the value is "invalid"
    When the configuration is decoded using the ValidateSpec
    Then diagnostics should contain 1 warning
    And the warning summary should be "OK"
    And the warning detail should be "validation called correctly"
    And the warning subject range should be "foobar:99,99-999,999"

  Scenario: RefineValueSpec - Decoding with Known, Unknown, Dynamic, and Marked Values
    Given a configuration:
      """
      foo = "hello"
      bar = unk
      dyn = dyn
      marked = mark(unk)
      """
    And an ObjectSpec with attributes "foo", "bar", "dyn", "marked"
    And each attribute uses a RefineValueSpec with a ValidateSpec that requires a non-null string
    And the RefineValueSpec refines the value to be NotNull
    And an evaluation context with:
      | variable | value                         |
      | unk      | unknown string                |
      | dyn      | dynamic                       |
    And a function "mark" that marks its input value with "boop"
    When the configuration is decoded
    Then the decoded object should have the following properties:
      | key    | value        | type   | refined   | marked |
      | foo    | "hello"      | string | false     | false  |
      | bar    | (unknown)    | string | NotNull   | false  |
      | dyn    | (unknown)    | string | NotNull   | false  |
      | marked | (unknown)    | string | NotNull   | boop   |
    And no decoding errors should occur
