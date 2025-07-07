# Covers fuzz tests in ./json/fuzz/fuzz_test.go
# Specifically, FuzzParse

Feature: JSON Parser Robustness (Fuzz Testing)
  This feature describes the fuzz testing applied to the HCL JSON parser.
  The goal of fuzz testing is to ensure the parser can handle arbitrary byte
  inputs without crashing, hanging, or exhibiting other unexpected behavior.

  Scenario: Parsing arbitrary byte inputs with json.Parse
    Given a fuzzing engine that generates arbitrary byte slice inputs
    When `json.Parse` is called with the arbitrary byte slice and a filename like "<fuzz-conf>"
    Then the `json.Parse` function must not panic or crash
    And the `json.Parse` function must not hang indefinitely
    And the `json.Parse` function must not consume excessive resources (e.g., memory, CPU)
    And the `json.Parse` function should either:
      | Outcome                                       |
      | Return a valid HCL File object and no errors  |
      | Return a (potentially partial) HCL File object and one or more diagnostics indicating parsing errors |
    # Note: This Gherkin scenario describes the property being fuzzed.
    # The fuzz test itself (FuzzParse) does not explicitly assert these conditions
    # but relies on the fuzzing engine to detect crashes, hangs, etc.
    # The Go test logs parsing errors if they occur, which aids in debugging
    # inputs that cause the fuzzer to report an issue.
