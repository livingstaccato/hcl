# Covers tests in ./hclsyntax/parse_traversal_test.go
# Specifically, TestParseTraversalAbs (which internally calls ParseTraversalAbs and ParseTraversalPartial)

Feature: HCL Syntax - Parsing Traversals
  This feature tests the parsing of HCL traversal strings into `hcl.Traversal` objects.
  It covers absolute traversals (starting with an identifier) and includes attribute access,
  literal index access (numeric), and splat operators. It also verifies correct
  diagnostic reporting for various syntax errors and unsupported constructs.

  Scenario Outline: Parsing HCL traversal strings
    Given an HCL traversal source string: "<source_string>"
    When `ParseTraversalAbs` (for non-splat tests) or `ParseTraversalPartial` (for splat tests) is called with the source string
    Then the number of diagnostics should be <diagnostics_count>
    And the resulting `hcl.Traversal` should be:
      | StepType      | Name | Key (for Index) | SourceRange         |
      | <Step1Type>   | <S1N>| <S1K>           | <S1Range>           |
      | <Step2Type>   | <S2N>| <S2K>           | <S2Range>           | # If applicable
      | <Step3Type>   | <S3N>| <S3K>           | <S3Range>           | # If applicable
      # ... more steps if needed, or fewer if traversal is shorter or nil

    Examples:
      | source_string | diagnostics_count | Step1Type    | S1N   | S1K           | S1Range           | Step2Type    | S2N   | S2K           | S2Range           | Step3Type    | S3N   | S3K | S3Range           |
      | `""`            | 1                 |              |       |               |                   |              |       |               |                   |              |       |     |                   | # Empty string: variable name required
      | `"foo"`         | 0                 | TraverseRoot | "foo" |               | L1C1-L1C4 (B0-B3) |              |       |               |                   |              |       |     |                   |
      | `"foo.bar.baz"` | 0                 | TraverseRoot | "foo" |               | L1C1-L1C4 (B0-B3) | TraverseAttr | "bar" |               | L1C4-L1C8 (B3-B7) | TraverseAttr | "baz" |     | L1C8-L1C12 (B7-B11) |
      | `"foo[1]"`      | 0                 | TraverseRoot | "foo" |               | L1C1-L1C4 (B0-B3) | TraverseIndex|       | NumberIntVal(1) | L1C4-L1C7 (B3-B6) |              |       |     |                   |
      | `"foo[1][2]"`   | 0                 | TraverseRoot | "foo" |               | L1C1-L1C4 (B0-B3) | TraverseIndex|       | NumberIntVal(1) | L1C4-L1C7 (B3-B6) | TraverseIndex|       | NumberIntVal(2) | L1C7-L1C10 (B6-B9) |
      | `"foo[1].bar"`  | 0                 | TraverseRoot | "foo" |               | L1C1-L1C4 (B0-B3) | TraverseIndex|       | NumberIntVal(1) | L1C4-L1C7 (B3-B6) | TraverseAttr | "bar" |     | L1C7-L1C11 (B6-B10)|
      | `"foo."`        | 1                 | TraverseRoot | "foo" |               | L1C1-L1C4 (B0-B3) |              |       |               |                   |              |       |     |                   | # Attribute name required
      | `"foo["`        | 1                 | TraverseRoot | "foo" |               | L1C1-L1C4 (B0-B3) |              |       |               |                   |              |       |     |                   | # Index required
      | `"foo[index]"`  | 1                 | TraverseRoot | "foo" |               | L1C1-L1C4 (B0-B3) |              |       |               |                   |              |       |     |                   | # Index must be literal
      | `"foo[0"`       | 1                 | TraverseRoot | "foo" |               | L1C1-L1C4 (B0-B3) | TraverseIndex|       | NumberIntVal(0) | L1C4-L1C6 (B3-B5) |              |       |     |                   | # Missing close bracket
      | `"foo 0"`       | 1                 | TraverseRoot | "foo" |               | L1C1-L1C4 (B0-B3) |              |       |               |                   |              |       |     |                   | # Extra junk after traversal
      | `"foo[*]"`      | 0                 | TraverseRoot | "foo" |               | L1C1-L1C4 (B0-B3) | TraverseSplat|       |               | L1C4-L1C7 (B3-B6) |              |       |     |                   | # Splat operator (using ParseTraversalPartial)
      | `"foo.*"`       | 1                 | TraverseRoot | "foo" |               | L1C1-L1C4 (B0-B3) |              |       |               |                   |              |       |     |                   | # Legacy splat not supported by ParseTraversalAbs
      | `"foo[*].bar"`  | 1                 | TraverseRoot | "foo" |               | L1C1-L1C4 (B0-B3) |              |       |               |                   |              |       |     |                   | # Attr after splat not supported by ParseTraversalAbs

    # Notes for the Traversal table:
    # - If a step is not applicable (e.g., only one step in traversal), subsequent Step/Name/Key/Range columns will be empty for that row.
    # - If the entire traversal is nil (e.g., for empty input), all step columns will be empty.
    # - Key is only applicable for TraverseIndex. Name is for TraverseRoot and TraverseAttr. TraverseSplat has neither.
    # - SourceRange format: L1C1-L1C4 (B0-B3) means Line 1, Col 1 to Line 1, Col 4 (Bytes 0 to 3).
    # - The test for "foo[*]" specifically uses ParseTraversalPartial. The test for "foo[*].bar" is skipped for ParseTraversalPartial as it's designed to fail for ParseTraversalAbs.
    # - The test for "foo.*" is specifically for ParseTraversalAbs to show it's not supported there.
