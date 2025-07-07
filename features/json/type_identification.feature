# Covers functions in ./json/is.go

Feature: JSON HCL Type Identification
  This feature tests the `IsJSONExpression` and `IsJSONBody` functions,
  which are used to determine if a given `hcl.Expression` or `hcl.Body`
  originated specifically from a JSON document (i.e., are instances of
  the `json` package's internal types).

  Scenario: IsJSONExpression correctly identifies a JSON-originated expression
    Given an `hcl.Expression` "jsonExpr" that was created by parsing a JSON source
    When `IsJSONExpression(jsonExpr)` is called
    Then the result should be true

  Scenario: IsJSONExpression correctly identifies a non-JSON-originated expression
    Given an `hcl.Expression` "nativeExpr" that was created by parsing HCL native syntax source
    When `IsJSONExpression(nativeExpr)` is called
    Then the result should be false

  Scenario: IsJSONExpression returns false for a wrapped JSON expression
    Given an `hcl.Expression` "jsonExpr" that was created by parsing a JSON source
    And "wrappedJsonExpr" is an `hcl.Expression` that wraps "jsonExpr" but is not itself a `json.expression`
    When `IsJSONExpression(wrappedJsonExpr)` is called
    Then the result should be false

  Scenario: IsJSONBody correctly identifies a JSON-originated body
    Given an `hcl.Body` "jsonBody" that was created by parsing a JSON source
    When `IsJSONBody(jsonBody)` is called
    Then the result should be true

  Scenario: IsJSONBody correctly identifies a non-JSON-originated body
    Given an `hcl.Body` "nativeBody" that was created by parsing HCL native syntax source
    When `IsJSONBody(nativeBody)` is called
    Then the result should be false

  Scenario: IsJSONBody returns false for a wrapped JSON body
    Given an `hcl.Body` "jsonBody" that was created by parsing a JSON source
    And "wrappedJsonBody" is an `hcl.Body` that wraps "jsonBody" but is not itself a `json.body`
    When `IsJSONBody(wrappedJsonBody)` is called
    Then the result should be false

    # Note:
    # - "created by parsing a JSON source" implies the object is of the internal type `*json.expression` or `*json.body`.
    # - "created by parsing HCL native syntax source" implies types like `*hclsyntax.LiteralValueExpr` or `*hclsyntax.Body`.
    # - "wrapper" implies a custom type that implements hcl.Expression/hcl.Body and holds another expression/body.
