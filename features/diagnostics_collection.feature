# Covers types and methods in ./diagnostic.go, focusing on the hcl.Diagnostics collection.

Feature: HCL Diagnostics Collection Management
  This feature tests the behavior of the `hcl.Diagnostics` type, which is a
  collection of individual `hcl.Diagnostic` instances. It covers how the
  collection represents itself as an error, how items are added, and how
  it's queried for the presence of errors.

  Scenario Outline: String representation of a Diagnostics collection via Error() method
    Given a `hcl.Diagnostics` list with the following diagnostics: <diagnostics_list_description>
      # Each diagnostic has a Severity, Summary, Detail, and optional Subject.
      # For simplicity, we'll assume Subject "S" for error string representation.
    When its `Error()` method is called
    Then the resulting string should be "<expected_error_string>"

    Examples:
      | diagnostics_list_description                 | expected_error_string                                           |
      | (empty list)                                 | "no diagnostics"                                                |
      | 1 Error: Sum="E1", Det="D1", Subj="S1"       | "S1: E1; D1"                                                    |
      | 2 Errors: (Sum="E1",Det="D1",Subj="S1"), (Sum="E2",Det="D2",Subj="S2") | "S1: E1; D1, and 1 other diagnostic(s)"                       |
      | 1 Warning: Sum="W1", Det="D1", Subj="S1"     | "S1: W1; D1"                                                    | # A warning also has an Error() string for the individual diagnostic
      | 1 Error (SubjectE, SummaryE, DetailE) then 1 Warning (SubjectW, SummaryW, DetailW) | "SubjectE: SummaryE; DetailE, and 1 other diagnostic(s)" |

  Scenario: Appending a single diagnostic to a Diagnostics list
    Given an empty `hcl.Diagnostics` list "diagsList"
    And a new `hcl.Diagnostic` "D1" with Severity Error, Summary "First Error"
    When "D1" is appended to "diagsList" using `Append`
    Then "diagsList" should now contain 1 diagnostic
    And the first diagnostic in "diagsList" should be "D1"
    Given another `hcl.Diagnostic` "D2" with Severity Warning, Summary "Second Warning"
    When "D2" is appended to "diagsList"
    Then "diagsList" should now contain 2 diagnostics
    And the second diagnostic in "diagsList" should be "D2"

  Scenario: Extending a Diagnostics list with another Diagnostics list
    Given a `hcl.Diagnostics` list "listA" containing "DiagnosticA1" (Error)
    And another `hcl.Diagnostics` list "listB" containing "DiagnosticB1" (Warning) and "DiagnosticB2" (Error)
    When "listA" is extended with "listB" using `Extend`
    Then "listA" should now contain 3 diagnostics
    And the diagnostics should be "DiagnosticA1", "DiagnosticB1", "DiagnosticB2" in that order

  Scenario Outline: Checking for the presence of errors in a Diagnostics list
    Given a `hcl.Diagnostics` list with the following severities: <severity_list>
    When `HasErrors()` is called on the list
    Then the result should be <has_errors_result>

    Examples:
      | severity_list                | has_errors_result |
      | (empty)                      | false             |
      | [Warning]                    | false             |
      | [Error]                      | true              |
      | [Warning, Error]             | true              |
      | [Warning, Warning]           | false             |
      | [Error, Error]               | true              |

  Scenario Outline: Retrieving only error diagnostics from a Diagnostics list
    Given a `hcl.Diagnostics` list: <diagnostics_list_with_severities>
      # Example: [Error("E1"), Warning("W1"), Error("E2")]
    When `Errs()` is called on the list
    Then the returned `[]error` slice should contain <count_of_errors> error(s)
    And these errors should correspond to the original Error diagnostics (e.g., E1, E2)
    And should not contain any Warning diagnostics

    Examples:
      | diagnostics_list_with_severities          | count_of_errors |
      | []                                        | 0               |
      | [Warning("W1")]                           | 0               |
      | [Error("E1")]                             | 1               |
      | [Warning("W1"), Error("E1")]              | 1               |
      | [Error("E1"), Warning("W1"), Error("E2")] | 2               |

    # Notes for tables:
    # - `diagnostics_list_description`: Describes the content of the hcl.Diagnostics list.
    #   Format like `1 Error: Sum="E1", Det="D1", Subj="S1"` means one diagnostic of type Error with given fields.
    # - `severity_list`: A list of DiagnosticSeverity values, e.g., `[Warning, Error]`.
    # - The `DiagnosticExtraUnwrapper` interface is for advanced users and its specific implementations
    #   would be tested with the features that produce such wrapped extra data.
    # - The `DiagnosticWriter` interface is tested by its concrete implementations like `DiagnosticTextWriter`.
