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
    # TransformerX adds "attr_x", TransformerY adds "attr_y"
    And TransformerX adds attribute "val" with initial value "X"
    And TransformerY modifies attribute "val", appending "Y" to its existing string value if it exists, otherwise sets it to "Y"
    When `transform.Chain` is called with `[TransformerX, TransformerY]` to create ChainedXY
    And ChainedXY is applied to the initial body
    Then the attribute "val" in the resulting body should have the value "XY"
    When `transform.Chain` is called with `[TransformerY, TransformerX]` to create ChainedYX
    And ChainedYX is applied to the initial body
    Then the attribute "val" in the resulting body should have the value "X" (TransformerY sets it to "Y", TransformerX overwrites to "X")

    # Note: The "Order of execution" scenario requires mock transformers with specific behaviors
    # to clearly demonstrate that TransformerA's output is TransformerB's input.
    # For simplicity in Gherkin, we describe the expected state after each transformation.
    # The mock implementations would need to be defined in the step definitions.
    # For the last example, TransformerY would need to be able to read the attribute set by TransformerX.
    # The example is simplified to show ordering. A more robust test would involve distinct modifications.
    # Let's refine the last scenario example for clarity:
    # TransformerX sets attr "step1" to "done"
    # TransformerY, if "step1" is "done", sets attr "step2" to "done"
    # Chain [X, Y] -> final body has step1="done", step2="done"
    # Chain [Y, X] -> final body has step1="done", but step2 is NOT "done" (because Y ran first)
