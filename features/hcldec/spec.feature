# Covers spec types and behaviors tested in ./hcldec/spec_test.go
# Related to spec definitions in ./hcldec/spec.go

Feature: HCL Decoding Specifications
  This feature covers specific HCL decoding specification types (`hcldec.Spec` implementations)
  and their distinct behaviors, such as handling defaults, custom validation, and value refinement.

  Scenario: DefaultSpec - Primary attribute is present and provides the value
    Given an HCL configuration:
      """
      foo = fooval
      bar = barval
      """
    And a DefaultSpec where:
      Primary is AttrSpec for "foo" of type String
      Default is AttrSpec for "bar" of type String
    And an evaluation context where variable "fooval" is "foo value" and "barval" is "bar value"
    When the configuration body is decoded using this DefaultSpec
    Then the decoded cty.Value should be String "foo value"
    And no diagnostics should be reported
    And when `hcldec.Variables` is called for this spec and body, the required traversals should include "fooval" and "barval"

  Scenario: DefaultSpec - Primary attribute is null, so default attribute provides the value
    Given an HCL configuration:
      """
      foo = fooval
      bar = barval
      """
    And a DefaultSpec where:
      Primary is AttrSpec for "foo" of type String
      Default is AttrSpec for "bar" of type String
    And an evaluation context where variable "fooval" is cty.NullVal(cty.String) and "barval" is "bar value"
    When the configuration body is decoded using this DefaultSpec
    Then the decoded cty.Value should be String "bar value"
    And no diagnostics should be reported

  Scenario Outline: ValidateSpec - Custom validation function execution and diagnostic subject handling
    Given an HCL configuration:
      """
      foo = "invalid"
      """
    And a ValidateSpec wrapping an AttrSpec for "foo" of type String
    And a validation function that:
      If input value is "invalid", returns a Warning diagnostic with Summary "OK", Detail "validation called correctly", and Subject <diagnostic_subject_range>
      Otherwise, returns an Error diagnostic with Summary "incorrect value"
    When the configuration body is decoded using this ValidateSpec
    Then 1 diagnostic should be reported
    And the diagnostic Severity should be Warning
    And the diagnostic Summary should be "OK"
    And the diagnostic Detail should be "validation called correctly"
    And the diagnostic Subject range should be <expected_final_subject_range>

    Examples:
      | diagnostic_subject_range         | expected_final_subject_range              |
      | (not set by validation func)     | (range of "foo" attribute's expression)   | # Auto-populated subject
      | "foobar:99,99-999,999" (explicit)| "foobar:99,99-999,999"                    | # Explicit subject preserved

  Scenario: RefineValueSpec - Applying NotNull refinement and preserving marks
    Given an HCL configuration:
      """
      foo = "hello"    # Known string
      bar = unk        # Unknown string
      dyn = dyn        # Dynamic value
      marked = mark(unk) # Marked unknown string
      """
    And an ObjectSpec with attributes "foo", "bar", "dyn", "marked", where each uses:
      A RefineValueSpec that applies a `.NotNull()` refinement, wrapping:
        A ValidateSpec that requires a non-null String for an AttrSpec (name matching attribute key, type String, required true)
    And an evaluation context with:
      Variable "unk" as cty.UnknownVal(cty.String)
      Variable "dyn" as cty.DynamicVal
      Function "mark" that takes any value and returns it marked with "boop"
    When the configuration body is decoded using this ObjectSpec and context
    Then no diagnostics should be reported
    And the decoded cty.Value should be an object with attributes:
      | Name   | ExpectedValue             | ExpectedType | IsRefinedNotNull | HasMark "boop" |
      | foo    | StringVal("hello")        | String       | true             | false          |
      | bar    | UnknownVal(String)        | String       | true             | false          |
      | dyn    | UnknownVal(String)        | String       | true             | false          |
      | marked | UnknownVal(String)        | String       | true             | true           |

    # Notes for tables:
    # - String "value" implies cty.StringVal("value").
    # - `(range of "foo" attribute's expression)` means the hcl.Range of the expression assigned to "foo".
    # - `IsRefinedNotNull` for an UnknownVal means it has the NotNull refinement. For a known value, it implies the ValidateSpec would've ensured it's not null.
    # - `HasMark "boop"` checks if the value is marked with "boop".
