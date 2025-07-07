# Covers fuzz tests in ./hclsyntax/fuzz/fuzz_test.go
# Specifically, FuzzParseTemplate, FuzzParseTraversalAbs, FuzzParseExpression, and FuzzParseConfig

Feature: HCL Syntax Parser Robustness (Fuzz Testing)
  This feature describes the fuzz testing applied to various HCL syntax parsing functions.
  The goal of fuzz testing is to ensure these parsers can handle arbitrary byte
  inputs without crashing, hanging, or exhibiting other unexpected behavior.
  For each parser, it should either parse successfully or return relevant diagnostics.

  Scenario: Fuzzing hclsyntax.ParseTemplate
    Given a fuzzing engine that generates arbitrary byte slice inputs for a template
    When `hclsyntax.ParseTemplate` is called with the arbitrary byte slice, a filename like "<fuzz-tmpl>", and a starting position
    Then the `hclsyntax.ParseTemplate` function must not panic or crash
    And the `hclsyntax.ParseTemplate` function must not hang indefinitely
    And the `hclsyntax.ParseTemplate` function must not consume excessive resources
    And the function should return either a valid HCL Expression or diagnostics indicating parsing errors

  Scenario: Fuzzing hclsyntax.ParseTraversalAbs
    Given a fuzzing engine that generates arbitrary byte slice inputs for an absolute traversal
    When `hclsyntax.ParseTraversalAbs` is called with the arbitrary byte slice, a filename like "<fuzz-trav>", and a starting position
    Then the `hclsyntax.ParseTraversalAbs` function must not panic or crash
    And the `hclsyntax.ParseTraversalAbs` function must not hang indefinitely
    And the `hclsyntax.ParseTraversalAbs` function must not consume excessive resources
    And the function should return either a valid HCL Traversal or diagnostics indicating parsing errors

  Scenario: Fuzzing hclsyntax.ParseExpression
    Given a fuzzing engine that generates arbitrary byte slice inputs for an expression
    When `hclsyntax.ParseExpression` is called with the arbitrary byte slice, a filename like "<fuzz-expr>", and a starting position
    Then the `hclsyntax.ParseExpression` function must not panic or crash
    And the `hclsyntax.ParseExpression` function must not hang indefinitely
    And the `hclsyntax.ParseExpression` function must not consume excessive resources
    And the function should return either a valid HCL Expression or diagnostics indicating parsing errors

  Scenario: Fuzzing hclsyntax.ParseConfig
    Given a fuzzing engine that generates arbitrary byte slice inputs for a configuration file
    When `hclsyntax.ParseConfig` is called with the arbitrary byte slice, a filename like "<fuzz-conf>", and a starting position
    Then the `hclsyntax.ParseConfig` function must not panic or crash
    And the `hclsyntax.ParseConfig` function must not hang indefinitely
    And the `hclsyntax.ParseConfig` function must not consume excessive resources
    And the function should return either a valid HCL File object or diagnostics indicating parsing errors

    # Note: These Gherkin scenarios describe the properties being fuzzed.
    # The Go fuzz tests themselves (e.g., FuzzParseConfig) do not explicitly assert these conditions
    # but rely on the fuzzing engine to detect crashes, hangs, etc.
    # The Go tests log parsing errors if they occur, which aids in debugging
    # inputs that cause the fuzzer to report an issue.
