# Covers tests in ./hcldec/variables_test.go
# Specifically, TestVariables

Feature: HCL Decoding Variable Extraction
  This feature covers how variables required by an HCL specification are extracted from a configuration body.

  Scenario Outline: Extracting Variables for Different Specs
    Given the HCL config:
      """
      <config>
      """
    And the HCL decoding spec: <spec_type>
    When variables are extracted from the body using the spec
    Then the extracted variables should be <expected_variables>

    Examples:
      | config               | spec_type                                                                 | expected_variables                                       |
      |                      | ObjectSpec                                                                | []                                                       |
      | a = foo              | ObjectSpec                                                                | []                                                       |
      | a = foo              | AttrSpec "a"                                                              | [foo (L1C5-L1C8)]                                        |
      | a = foo\nb = bar     | DefaultSpec Primary: AttrSpec "a", Default: AttrSpec "b"                    | [foo (L1C5-L1C8), bar (L2C5-L2C8)]                       |
      | a = foo              | ObjectSpec with "a": AttrSpec "a"                                         | [foo (L1C5-L1C8)]                                        |
      | b {\n  a = foo\n}    | BlockSpec "b", Nested: AttrSpec "a"                                       | [foo (L3C7-L3C10)]                                       |
      | b {\n  a = foo\n  b = bar\n} | BlockAttrsSpec "b", ElementType: String                             | [foo (L3C7-L3C10), bar (L4C7-L4C10)]                       |
      | b {\n  a = foo\n}\nb {\n  a = bar\n}\nc {\n  a = baz\n} | BlockListSpec "b", Nested: AttrSpec "a" | [foo (L3C7-L3C10), bar (L6C7-L6C10)]                       |

  # Note: The <expected_variables> column uses a simplified format.
  # In the actual test, these are hcl.Traversal objects with full source range information.
  # e.g., foo (L1C5-L1C8) means a TraverseRoot for "foo" with start line 1, col 5 and end line 1, col 8.
