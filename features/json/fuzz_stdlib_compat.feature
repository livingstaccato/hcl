# This BDD feature file corresponds to the Go fuzz test file:
# ./json/fuzz_stdlib_test.go
#
# It covers the following Go fuzz test:
# - FuzzStdlibCompat

Feature: HCL JSON Parser Standard Library Compatibility Fuzzing
  This feature describes the property that for JSON inputs considered valid by both
  Go's standard library `encoding/json` and HCL's JSON parser (`json.Parse`),
  the semantic interpretation of the data should be equivalent. The fuzz test
  aims to find discrepancies.

  Background:
    Given the HCL JSON parsing context
    And the Go standard library JSON parsing context

  Scenario: Semantic equivalence for mutually valid JSON inputs
    This scenario captures the core property tested by `FuzzStdlibCompat`.
    The fuzzer generates various byte inputs.

    Given an arbitrary byte stream as input
    When the input is successfully unmarshalled by `encoding/json.Unmarshal` into a Go native data structure "StdLibData"
    And the same input is successfully parsed by HCL's `json.Parse` into an HCL File "HCLFile"
    And "StdLibData" is converted to a cty.Value "ExpectedCtyValue" using `ctyjson.GoJSON`
    And "HCLFile" is processed (e.g., via `Body.Content` with a schema capturing the root) to obtain a cty.Value "ActualCtyValue"
    And "ExpectedCtyValue" is marshalled back to JSON bytes "ExpectedJSONBytes" using `ctyjson.Marshal`
    And "ActualCtyValue" is marshalled back to JSON bytes "ActualJSONBytes" using `ctyjson.Marshal`
    And "ExpectedJSONBytes" are unmarshalled using `encoding/json.Unmarshal` into a Go interface "FinalExpectedData"
    And "ActualJSONBytes" are unmarshalled using `encoding/json.Unmarshal` into a Go interface "FinalActualData"
    Then "FinalActualData" should be deeply equal to "FinalExpectedData" (using `reflect.DeepEqual`)
    And the fuzz test should report a failure if this deep equality check fails, indicating a semantic incompatibility.

    # Note: The multi-step re-marshalling and unmarshalling is done in the Go test
    # to achieve a canonical comparison form that ignores cty-specific number types
    # and JSON object key order differences. The BDD describes this desired end-state
    # of semantic equivalence.
```
