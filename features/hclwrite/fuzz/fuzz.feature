# Covers fuzz tests in ./hclwrite/fuzz/fuzz_test.go
# Specifically, FuzzParseConfig

Feature: HCLWrite Parser and Writer Robustness (Fuzz Testing)
  This feature describes the fuzz testing applied to the `hclwrite.ParseConfig` function
  and the subsequent `file.WriteTo` method. The goal is to ensure that the parser
  can handle arbitrary byte inputs without crashing or hanging, and that if a
  configuration is successfully parsed, it can also be successfully written out.

  Scenario: Parsing and Writing arbitrary HCL configurations
    Given a fuzzing engine that generates arbitrary byte slice inputs for an HCL configuration
    When `hclwrite.ParseConfig` is called with the arbitrary byte slice, a filename like "<fuzz-conf>", and a starting position
    Then the `hclwrite.ParseConfig` function must not panic or crash
    And the `hclwrite.ParseConfig` function must not hang indefinitely
    And the `hclwrite.ParseConfig` function must not consume excessive resources
    And if `hclwrite.ParseConfig` returns no error diagnostics (i.e., considers the input valid or recoverable)
    Then calling `WriteTo(io.Discard)` on the returned `hclwrite.File` object must not return an error
    And the `WriteTo` method must also not panic, hang, or consume excessive resources

    # Note: This Gherkin scenario describes the properties being fuzzed.
    # The Go fuzz test (FuzzParseConfig) relies on the fuzzing engine to detect
    # crashes/hangs during parsing. It explicitly fails if WriteTo returns an error
    # after a successful parse (no diagnostics).
    # Parsing errors from ParseConfig are logged but do not cause a test failure by themselves.
