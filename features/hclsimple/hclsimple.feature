# Covers functions in ./hclsimple/hclsimple.go
# Based on examples and tests in ./hclsimple/hclsimple_test.go
# and analysis of hclsimple.go for more comprehensive coverage.

Feature: hclsimple - Simplified HCL Decoding into Go Structs
  This feature tests the `hclsimple` package, which provides high-level functions
  `Decode` and `DecodeFile` for parsing HCL (native or JSON) and decoding it
  directly into Go struct values.

  Background:
    Given a Go struct `SimpleConfig` defined as:
      """
      type SimpleConfig struct {
          Foo string `hcl:"foo"`
          Baz string `hcl:"baz"`
      }
      """
    And an instance `targetConfig` of `SimpleConfig`.
    And a nil `hcl.EvalContext` named `nilContext`.

  Scenario: Decoding HCL native syntax from a byte slice using hclsimple.Decode
    Given an HCL native syntax string: `foo = "bar"\nbaz = "boop"\n`
    And filename "example.hcl"
    When `hclsimple.Decode` is called with filename, the string bytes, `nilContext`, and a pointer to `targetConfig`
    Then the operation should succeed (return nil error)
    And `targetConfig.Foo` should be "bar"
    And `targetConfig.Baz` should be "boop"

  Scenario: Decoding HCL JSON syntax from a byte slice using hclsimple.Decode
    Given an HCL JSON syntax string: `{\n  "foo": "bar_json",\n  "baz": "boop_json"\n}\n`
    And filename "example.json"
    When `hclsimple.Decode` is called with filename, the string bytes, `nilContext`, and a pointer to `targetConfig`
    Then the operation should succeed
    And `targetConfig.Foo` should be "bar_json"
    And `targetConfig.Baz` should be "boop_json"

  Scenario: hclsimple.Decode fails for unsupported file extension
    Given an HCL native syntax string: `foo = "bar"\n`
    And filename "example.txt" (unsupported extension)
    When `hclsimple.Decode` is called with filename, the string bytes, `nilContext`, and a pointer to `targetConfig`
    Then the operation should fail
    And the diagnostics should contain an error with Summary "Unsupported file format"
    And the Detail should mention "unrecognized file format suffix \".txt\""

  Scenario: hclsimple.Decode propagates parsing errors (native syntax)
    Given an invalid HCL native syntax string: `foo = "bar` (unterminated string)
    And filename "error.hcl"
    When `hclsimple.Decode` is called with filename, the string bytes, `nilContext`, and a pointer to `targetConfig`
    Then the operation should fail
    And the diagnostics should contain an error with Summary "Unterminated template string" (from hclsyntax parser)

  Scenario: hclsimple.Decode propagates parsing errors (JSON syntax)
    Given an invalid HCL JSON syntax string: `{"foo": "bar",,}` (double comma)
    And filename "error.json"
    When `hclsimple.Decode` is called with filename, the string bytes, `nilContext`, and a pointer to `targetConfig`
    Then the operation should fail
    And the diagnostics should contain an error (e.g., from json parser about unexpected token)

  Scenario: hclsimple.Decode propagates decoding errors from gohcl.DecodeBody
    Given an HCL native syntax string: `foo = "bar"\nunexpected_attr = true\n`
    And filename "decode_error.hcl"
    And `SimpleConfig` struct (which only expects "foo" and "baz")
    When `hclsimple.Decode` is called with filename, the string bytes, `nilContext`, and a pointer to `targetConfig`
    Then the operation should fail
    And the diagnostics should contain an error with Summary "Unsupported argument" for "unexpected_attr" (from gohcl)

  Scenario: Decoding an HCL native syntax file using hclsimple.DecodeFile
    Given a file named "testdata/test_native_decode.hcl" with content: `foo = "file_bar"\nbaz = "file_boop"\n`
    When `hclsimple.DecodeFile` is called with "testdata/test_native_decode.hcl", `nilContext`, and a pointer to `targetConfig`
    Then the operation should succeed
    And `targetConfig.Foo` should be "file_bar"
    And `targetConfig.Baz` should be "file_boop"

  Scenario: Decoding an HCL JSON syntax file using hclsimple.DecodeFile
    Given a file named "testdata/test_json_decode.json" with content: `{\n  "foo": "file_json_bar",\n  "baz": "file_json_boop"\n}\n`
    When `hclsimple.DecodeFile` is called with "testdata/test_json_decode.json", `nilContext`, and a pointer to `targetConfig`
    Then the operation should succeed
    And `targetConfig.Foo` should be "file_json_bar"
    And `targetConfig.Baz` should be "file_json_boop"

  Scenario: hclsimple.DecodeFile fails if file not found
    Given a non-existent filename "ghost.hcl"
    When `hclsimple.DecodeFile` is called with "ghost.hcl", `nilContext`, and a pointer to `targetConfig`
    Then the operation should fail
    And the diagnostics should contain an error with Summary "Configuration file not found"
    And the Detail should mention "ghost.hcl does not exist"

  Scenario: hclsimple.DecodeFile fails if file is unreadable (conceptual)
    Given a filename "unreadable.hcl" that exists but is unreadable (e.g., due to permissions)
    When `hclsimple.DecodeFile` is called with "unreadable.hcl", `nilContext`, and a pointer to `targetConfig`
    Then the operation should fail
    And the diagnostics should contain an error with Summary "Failed to read configuration"
    And the Detail should mention "Can't read unreadable.hcl" and the OS-level error

    # Note: The "unreadable file" scenario is conceptual as creating such a state
    # in a platform-independent way for a BDD step definition can be complex.
    # The Go code handles os.ReadFile errors.
