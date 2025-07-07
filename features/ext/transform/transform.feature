# Covers functions in ./ext/transform/transform.go
# Based on test cases in ./ext/transform/transform_test.go (TestDeep)
# and analysis of transform.go for public APIs.

Feature: HCL Body Transformation Utilities
  This feature tests utilities for applying transformations to HCL bodies,
  including shallow (top-level only) and deep (recursive) transformations.

  Background:
    Given a Transformer "RemoveBlockTypeRemove" that removes any block of type "remove" from a body.
    And an HCL Body "OriginalBody" defined as:
      Attributes: {"true": LiteralExpression(cty.True)}
      Blocks:
        - Type: "remove", Labels: [], Body: (empty)
        - Type: "child", Labels: [], Body: (containing a single block: Type: "remove", Labels: [], Body: (empty))

  Scenario: Deeply applying a transformer to recursively modify a body and its nested block bodies
    Given the "OriginalBody" and the "RemoveBlockTypeRemove" transformer
    When `transform.Deep(OriginalBody, RemoveBlockTypeRemove)` is called to get "WrappedBody"
    And the content of "WrappedBody" is requested with a schema for attribute "true" and block "child"
    Then no diagnostics should be reported for the root content retrieval
    And the root content attributes should contain "true" with value cty.True
    And the root content should contain 1 block
    And this block should have type "child" (the top-level "remove" block is gone)
    When the content of this "child" block's body is requested with an empty schema
    Then no diagnostics should be reported for the child content retrieval
    And the child content should have no attributes
    And the child content should have no blocks (the nested "remove" block is also gone)

  Scenario: Shallowly applying a transformer to modify only the top-level body
    Given the "OriginalBody" and the "RemoveBlockTypeRemove" transformer
    When `transform.Shallow(OriginalBody, RemoveBlockTypeRemove)` is called to get "TransformedShallowBody"
    And the content of "TransformedShallowBody" is requested with a schema for attribute "true" and block "child"
    Then no diagnostics should be reported for the root content retrieval
    And the root content attributes should contain "true" with value cty.True
    And the root content should contain 1 block
    And this block should have type "child" (the top-level "remove" block is gone)
    When the content of this "child" block's body is requested with an empty schema for block "remove"
    Then no diagnostics should be reported for the child content retrieval
    And the child content should contain 1 block of type "remove" (the nested "remove" block is NOT gone)

    # Notes for table values:
    # - LiteralExpression(cty.True) represents an hcl.Expression that evaluates to cty.True.
    # - (empty) for a body means an hcl.EmptyBody or a body that would produce no attributes/blocks for an empty schema.
    # - The `deepWrapper` type itself is internal; these scenarios test the behavior of the public `Deep` and `Shallow` functions.
