# Covers functions in ./ext/transform/error.go

Feature: HCL Body Diagnostic Handling Utilities
  This feature tests utilities for creating HCL Body objects that are primarily
  concerned with managing and returning diagnostics, often used by Transformers.
  It covers `NewErrorBody` for bodies that only represent errors, and
  `BodyWithDiagnostics` for wrapping existing bodies with additional diagnostics.

  Background:
    Given a mock `hcl.Body` named "MockOriginalBody".
    And when "MockOriginalBody.Content" is called with any schema, it returns "OriginalContent" and "OriginalDiags".
    And when "MockOriginalBody.PartialContent" is called, it returns "OriginalContent", "OriginalRemainBody", and "OriginalDiags".
    And when "MockOriginalBody.JustAttributes" is called, it returns "OriginalAttributes" and "OriginalDiags".
    And "OriginalContent" contains attribute "original_attr" = "val".
    And "OriginalDiags" is an empty hcl.Diagnostics list.

  Scenario: NewErrorBody returns provided error diagnostics and empty content
    Given an `hcl.Diagnostics` list "ErrorDiags" containing one hcl.DiagError "Fatal Transformation Error"
    When `NewErrorBody(ErrorDiags)` is called to create "ErrorBody"
    When "ErrorBody.Content" is called with an empty schema
    Then the returned hcl.BodyContent should be empty or contain only a MissingItemRange
    And the returned diagnostics should be "ErrorDiags"
    When "ErrorBody.PartialContent" is called with an empty schema
    Then the returned hcl.BodyContent should be empty or contain only a MissingItemRange
    And the returned 'remaining' hcl.Body might be a placeholder or the original error body
    And the returned diagnostics should be "ErrorDiags"
    When "ErrorBody.JustAttributes" is called
    Then the returned hcl.Attributes should be nil or empty
    And the returned diagnostics should be "ErrorDiags"

  Scenario: NewErrorBody panics if no error diagnostics are provided
    Given an `hcl.Diagnostics` list "WarningDiags" containing only a hcl.DiagWarning "Just a warning"
    When `NewErrorBody(WarningDiags)` is called
    Then the operation should panic with message "NewErrorBody called without any error diagnostics"

  Scenario: BodyWithDiagnostics short-circuits if initial diagnostics contain errors
    Given "MockOriginalBody"
    And an `hcl.Diagnostics` list "InitialErrorDiags" containing one hcl.DiagError "Initial Error Occurred"
    When `BodyWithDiagnostics(MockOriginalBody, InitialErrorDiags)` is called to create "WrappedErrorBody"
    When "WrappedErrorBody.Content" is called with a schema for "original_attr"
    Then the returned hcl.BodyContent should be empty or contain only a MissingItemRange
    And the returned diagnostics should be "InitialErrorDiags" (and not include "OriginalDiags")
    When "WrappedErrorBody.PartialContent" is called with a schema for "original_attr"
    Then the returned hcl.BodyContent should be empty or contain only a MissingItemRange
    And the returned 'remaining' hcl.Body should be "MockOriginalBody"
    And the returned diagnostics should be "InitialErrorDiags"
    When "WrappedErrorBody.JustAttributes" is called
    Then the returned hcl.Attributes should be nil or empty
    And the returned diagnostics should be "InitialErrorDiags"

  Scenario: BodyWithDiagnostics merges initial warnings with wrapped body's results
    Given "MockOriginalBody"
    And an `hcl.Diagnostics` list "InitialWarningDiags" containing one hcl.DiagWarning "Initial Warning Message"
    And "OriginalDiags" from "MockOriginalBody.Content" is modified to also contain a hcl.DiagWarning "Wrapped Body Warning"
    When `BodyWithDiagnostics(MockOriginalBody, InitialWarningDiags)` is called to create "WrappedWarningBody"
    When "WrappedWarningBody.Content" is called with a schema for "original_attr"
    Then the returned hcl.BodyContent should be "OriginalContent" (containing "original_attr")
    And the returned diagnostics should contain "Initial Warning Message"
    And the returned diagnostics should contain "Wrapped Body Warning"
    And the returned diagnostics should not have errors

  Scenario: BodyWithDiagnostics returns original body if initial diagnostics are empty
    Given "MockOriginalBody"
    And an empty `hcl.Diagnostics` list "EmptyDiags"
    When `BodyWithDiagnostics(MockOriginalBody, EmptyDiags)` is called
    Then the returned hcl.Body should be the same instance as "MockOriginalBody"

  Scenario: MissingItemRange for diagBody
    Given an `hcl.Diagnostics` list "ErrorDiags" containing one hcl.DiagError "Some Error"
    And "ErrorBody" is created with `NewErrorBody(ErrorDiags)`
    When `ErrorBody.MissingItemRange()` is called
    Then it returns a placeholder range with filename "<empty>"
    Given "MockOriginalBody" whose `MissingItemRange()` returns "mock_missing_range"
    And "WrappedBody" is created with `BodyWithDiagnostics(MockOriginalBody, ErrorDiags)`
    When `WrappedBody.MissingItemRange()` is called
    Then it returns "mock_missing_range"

    # Notes:
    # - "empty or contain only a MissingItemRange" for BodyContent means no attributes or blocks.
    # - "placeholder or the original error body" for PartialContent's remain means its exact nature might vary but it carries the error.
    # - The interaction with `MissingItemRange` is also covered.
