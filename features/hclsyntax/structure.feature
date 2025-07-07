# Covers tests in ./hclsyntax/structure_test.go
# Specifically, TestBodyContent and TestBodyJustAttributes

Feature: HCL Syntax - Body Structure and Content Retrieval
  This feature tests how an `hclsyntax.Body` object provides its content
  (attributes and blocks) based on a given `hcl.BodySchema`. It covers
  both full content retrieval (`Content`) and partial content retrieval
  (`PartialContent`), as well as attribute-only retrieval (`JustAttributes`).
  Diagnostic reporting for schema mismatches (e.g., missing required attributes,
  unexpected items) is also verified.

  Scenario Outline: Retrieving content from an hclsyntax.Body
    Given an `hclsyntax.Body` constructed with:
      | Attributes (Name:Expr) | Blocks (Type:Labels) | HiddenAttrs (Names) |
      | <initial_attrs>        | <initial_blocks>     | <hidden_attrs>      |
    And an `hcl.BodySchema` defined with:
      | SchemaAttributes (Name:Required) | SchemaBlocks (Type:LabelNames) |
      | <schema_attrs>                   | <schema_blocks>                |
    When the body's content is requested using <retrieval_method> with the schema
    Then the number of diagnostics should be <expected_diag_count>
    And the returned `hcl.BodyContent` should have attributes: <expected_content_attrs>
    And the returned `hcl.BodyContent` should have blocks: <expected_content_blocks>

    Examples:
      # Full Content (partial=false)
      | initial_attrs          | initial_blocks               | hidden_attrs | schema_attrs                   | schema_blocks                     | retrieval_method | expected_diag_count | expected_content_attrs        | expected_content_blocks         |
      | {}                     | []                           | []           | {}                             | []                                | Content          | 0                   | {}                              | []                              | # Empty body, empty schema
      | {foo:Expr}             | []                           | []           | [{Name:foo}]                   | []                                | Content          | 0                   | {foo:Attr(foo)}                 | []                              | # Attribute requested
      | {foo:Expr}             | []                           | []           | {}                             | []                                | Content          | 1                   | {}                              | []                              | # Attribute not expected
      | {}                     | []                           | []           | [{Name:foo,Required:true}]     | []                                | Content          | 1                   | {}                              | []                              | # Required attribute missing
      | {foo:Expr}             | []                           | []           | []                             | [{Type:foo}]                      | Content          | 1                   | {}                              | []                              | # Attribute defined, block expected
      | []                     | [{Type:foo}]                 | []           | []                             | [{Type:foo}]                      | Content          | 0                   | {}                              | [Block(foo)]                    | # Block requested
      | []                     | [{Type:foo},{Type:foo}]      | []           | []                             | [{Type:foo}]                      | Content          | 0                   | {}                              | [Block(foo),Block(foo)]         | # Multiple blocks of same type
      | []                     | [{Type:foo},{Type:bar}]      | []           | []                             | [{Type:foo}]                      | Content          | 1                   | {}                              | [Block(foo)]                    | # Unexpected block "bar"
      | []                     | [{Type:foo,Labels:["l"]}]    | []           | []                             | [{Type:foo,LabelNames:["n"]}]     | Content          | 0                   | {}                              | [Block(foo, Labels:["l"])]      | # Block with label
      | []                     | [{Type:foo}]                 | []           | []                             | [{Type:foo,LabelNames:["n"]}]     | Content          | 1                   | {}                              | []                              | # Block missing required label
      | []                     | [{Type:foo,Labels:["l"]}]    | []           | []                             | [{Type:foo}]                      | Content          | 1                   | {}                              | []                              | # Block has label, none expected
      | []                     | [{Type:foo,Labels:["l1","l2"]}]| []         | []                             | [{Type:foo,LabelNames:["n"]}]     | Content          | 1                   | {}                              | []                              | # Block has too many labels
      # Partial Content (partial=true)
      | {foo:Expr}             | []                           | []           | {}                             | []                                | PartialContent   | 0                   | {}                              | []                              | # Attribute not in schema, but partial mode
      | []                     | [{Type:foo},{Type:bar}]      | []           | []                             | [{Type:foo}]                      | PartialContent   | 0                   | {}                              | [Block(foo)]                    | # Unexpected block "bar", but partial mode

  Scenario Outline: Retrieving JustAttributes from an hclsyntax.Body
    Given an `hclsyntax.Body` constructed with:
      | Attributes (Name:Expr) | Blocks (Type:Labels) | HiddenAttrs (Names) |
      | <initial_attrs>        | <initial_blocks>     | <hidden_attrs>      |
    When the body's `JustAttributes` method is called
    Then the number of diagnostics should be <expected_diag_count>
    And the returned `hcl.Attributes` map should be <expected_attrs_map>

    Examples:
      | initial_attrs          | initial_blocks | hidden_attrs | expected_diag_count | expected_attrs_map            |
      | {}                     | []             | []           | 0                   | {}                            |
      | {foo:Expr(Str("bar"))} | []             | []           | 0                   | {foo:Attr(foo,Expr(Str("bar")))}|
      | {foo:Expr(Str("bar"))} | [{Type:foo}]   | []           | 1                   | {foo:Attr(foo,Expr(Str("bar")))}| # Blocks not allowed
      | {foo:Expr(Str("bar"))} | []             | ["foo"]      | 0                   | {}                            | # Attribute "foo" is hidden

    # Notes for table representation:
    # - Attributes (Name:Expr): Simplified. `Expr` implies an hclsyntax.Expression, `Expr(Str("bar"))` implies a LiteralValueExpr for cty.StringVal("bar").
    # - Blocks (Type:Labels): [{Type:"foo", Labels:["l1","l2"]}].
    # - HiddenAttrs (Names): A list of attribute names that are considered "hidden" or already processed.
    # - SchemaAttributes (Name:Required): [{Name:"foo", Required:true}].
    # - SchemaBlocks (Type:LabelNames): [{Type:"foo", LabelNames:["name"]}].
    # - Attr(name, Expr): Simplified hcl.Attribute.
    # - Block(type, Labels): Simplified hcl.Block.
    # - {} for maps means empty. [] for lists/blocks means empty.
    # - The `Expr` in `expected_content_attrs` will be the same as the one in `initial_attrs`.
    # - The `Body` of `expected_content_blocks` will be `(*hclsyntax.Body)(nil)` as per the Go test structure.
