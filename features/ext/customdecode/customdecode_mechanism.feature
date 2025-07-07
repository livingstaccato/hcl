# Covers functionalities in ./ext/customdecode/customdecode.go
# Specifically, the CustomExpressionDecoder mechanism and CustomExpressionDecoderForType function.

Feature: HCL Custom Expression Decoding Mechanism
  This feature tests the mechanism that allows cty.CapsuleType instances to provide
  custom logic for decoding HCL expressions, overriding standard evaluation.
  It focuses on the `CustomExpressionDecoderForType` function which retrieves
  such custom decoders.

  Scenario: Retrieving a registered CustomExpressionDecoderFunc from a supporting CapsuleType
    Given a `cty.CapsuleType` named "DecodingCapsule"
    And "DecodingCapsule" has a specific `CustomExpressionDecoderFunc` registered for the `CustomExpressionDecoder` extension key
    When `customdecode.CustomExpressionDecoderForType` is called with "DecodingCapsule"
    Then the returned function should be the specific `CustomExpressionDecoderFunc` registered by "DecodingCapsule"
    And the returned function should not be nil

  Scenario: Attempting to retrieve CustomExpressionDecoderFunc from a CapsuleType that does not support it
    Given a `cty.CapsuleType` named "NonDecodingCapsule"
    And "NonDecodingCapsule" does NOT have a function registered for the `CustomExpressionDecoder` extension key
    When `customdecode.CustomExpressionDecoderForType` is called with "NonDecodingCapsule"
    Then the returned function should be nil

  Scenario: Attempting to retrieve CustomExpressionDecoderFunc from a non-CapsuleType
    Given a non-capsule `cty.Type` (e.g., `cty.String`)
    When `customdecode.CustomExpressionDecoderForType` is called with this non-capsule type
    Then the returned function should be nil

    # Notes:
    # - "DecodingCapsule" and "NonDecodingCapsule" are conceptual types for these scenarios.
    #   In actual HCL, types like `typeexpr.TypeConstraintType` or `customdecode.ExpressionType`
    #   would be examples of "DecodingCapsule".
    # - The behavior of the CustomExpressionDecoderFunc itself (i.e., how it processes an hcl.Expression)
    #   is tested by the features for the specific capsule types that implement it (e.g., features for typeexpr or hcldec_into_expr).
    # - This feature focuses on the discovery mechanism provided by `CustomExpressionDecoderForType`.
