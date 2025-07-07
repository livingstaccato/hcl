# Covers functionalities in ./ext/transform/transformer.go
# Specifically, the Chain function and the Transformer interface concept.

Feature: HCL Body Transformer Chaining
  This feature tests the `transform.Chain` function, which combines multiple
  `hcl.Transformer` instances into a single transformer that applies them
  sequentially.

  Background:
    Given mock HCL bodies and transformers.
    And TransformerA is a mock transformer that adds an attribute `attr_a = "val_a"` to a body.
    And TransformerB is a mock transformer that appends a block `block_b {}` to a body.
    And TransformerNoOp is a mock transformer that returns the input body unchanged.

  Scenario: Chaining two active transformers
    Given an initial empty HCL Body
    When `transform.Chain` is called with `[TransformerA, TransformerB]` to create ChainedTransformer
    And ChainedTransformer is applied to the initial body to get the final body
    Then the final body should contain an attribute "attr_a" with value "val_a"
    And the final body should contain a block of type "block_b"

  Scenario: Chaining an active transformer with a no-op transformer
    Given an initial empty HCL Body
    When `transform.Chain` is called with `[TransformerA, TransformerNoOp]` to create ChainedTransformer
    And ChainedTransformer is applied to the initial body to get the final body
    Then the final body should contain an attribute "attr_a" with value "val_a"
    And the final body should not contain a block of type "block_b" (or any other unexpected changes)

  Scenario: Chaining a no-op transformer with an active transformer
    Given an initial empty HCL Body
    When `transform.Chain` is called with `[TransformerNoOp, TransformerA]` to create ChainedTransformer
    And ChainedTransformer is applied to the initial body to get the final body
    Then the final body should contain an attribute "attr_a" with value "val_a"
    And the final body should not contain a block of type "block_b"

  Scenario: Chaining an empty list of transformers
    Given an initial HCL Body (e.g., containing `original_attr = 1`)
    When `transform.Chain` is called with an empty list of transformers to create ChainedTransformer
    And ChainedTransformer is applied to the initial body to get the final body
    Then the final body should be identical to the initial body (e.g., still contains `original_attr = 1` and nothing else)

  Scenario: Order of execution in a chain
    Given an initial empty HCL Body
    # TransformerX sets attribute "step1" to "done"
    # TransformerY sets attribute "step2" to "done" only if attribute "step1" is already "done"
    Given TransformerX that sets attribute "step1" to "done"
    And TransformerY that sets attribute "step2" to "done" if "step1" is "done"
    When `transform.Chain` is called with `[TransformerX, TransformerY]` to create ChainedXY
    And ChainedXY is applied to the initial empty HCL Body to get "BodyXY"
    Then attribute "step1" in "BodyXY" should have value "done"
    And attribute "step2" in "BodyXY" should have value "done"
    When `transform.Chain` is called with `[TransformerY, TransformerX]` to create ChainedYX
    And ChainedYX is applied to the initial empty HCL Body to get "BodyYX"
    Then attribute "step1" in "BodyYX" should have value "done"
    And attribute "step2" in "BodyYX" should not exist or not be "done"
