# Covers tests in ./ext/transform/transform_test.go
# Specifically, TestDeep

Feature: Deep Body Transformation
  This feature tests the `Deep` transformer, which recursively applies
  a given transformation function to an HCL body and all of its nested
  block bodies.

  Scenario: Applying a transformer that removes "remove" blocks recursively
    Given an HCL body `src` with the following structure:
      - Attribute "true" = true (literal)
      - Block "remove" {}
      - Block "child" {
          Block "remove" {}
        }
    And a transformer function `testTransform` that:
      - Partially decodes its input body for blocks of type "remove".
      - Returns the remaining body along with any diagnostics from the partial decode.
    When the `Deep` transformer is applied to `src` with `testTransform` to produce `wrapped` body
    And the content of `wrapped` is requested with a schema for:
      - Attribute "true"
      - Block "child"
    Then no diagnostics should be reported for the root content
    And the root content attributes should include "true" with value true
    And the root content should contain 1 block
    And this block should be of type "child"
    When the content of this "child" block's body is requested with an empty schema
    Then no diagnostics should be reported for the child content
    And the child content should have no attributes
    And the child content should have no blocks (the nested "remove" block was removed)
