# This BDD feature file corresponds to the Go file:
# ./json/ast.go
#
# This file describes the internal Abstract Syntax Tree (AST) nodes used by the
# HCL JSON parser. These nodes represent the raw structure of a parsed JSON
# document before it's converted into hcl.File or hcl.Expression.
# As these are internal types, the scenarios are descriptive rather than
# directly executable test cases against a public API.

Feature: HCL JSON Internal AST Node Structure
  This feature describes the internal Abstract Syntax Tree (AST) nodes
  that the HCL JSON parser constructs. These nodes are an intermediate
  representation of the JSON input.

  Scenario: Common Node Interface
    All internal JSON AST nodes implement a common `node` interface.
    Given an internal JSON AST node
    Then it must provide a `Range()` method returning its full hcl.Range in the source
    And it must provide a `StartRange()` method returning the hcl.Range of its opening token(s) (or full range for literals)

  Scenario: Object Value Node (`objectVal`)
    The `objectVal` node represents a JSON object (`{ ... }`).
    Given a parsed JSON object
    Then it is represented internally by an `objectVal` node
    And this node contains a list of `objectAttr` nodes for its key/value pairs
    And it stores the `SrcRange` for the entire object (from `{` to `}`)
    And it stores the `OpenRange` for the opening brace `{`
    And it stores the `CloseRange` for the closing brace `}`

  Scenario: Object Attribute Node (`objectAttr`)
    The `objectAttr` node represents a single key-value pair within a JSON object.
    Given a key-value pair within a parsed JSON object
    Then it is represented internally by an `objectAttr` node
    And this node contains the attribute `Name` as a string
    And this node contains the attribute `Value` as another AST `node` (e.g., stringVal, numberVal, objectVal, etc.)
    And it stores the `NameRange` for the source range of the attribute's name string.

  Scenario: Array Value Node (`arrayVal`)
    The `arrayVal` node represents a JSON array (`[ ... ]`).
    Given a parsed JSON array
    Then it is represented internally by an `arrayVal` node
    And this node contains a list of `Values`, where each value is another AST `node`
    And it stores the `SrcRange` for the entire array (from `[` to `]`)
    And it stores the `OpenRange` for the opening bracket `[`

  Scenario: Boolean Value Node (`booleanVal`)
    The `booleanVal` node represents a JSON boolean literal (`true` or `false`).
    Given a parsed JSON boolean literal
    Then it is represented internally by a `booleanVal` node
    And this node contains the parsed `Value` as a Go bool
    And it stores the `SrcRange` for the literal in the source.

  Scenario: Number Value Node (`numberVal`)
    The `numberVal` node represents a JSON number literal.
    Given a parsed JSON number literal
    Then it is represented internally by a `numberVal` node
    And this node contains the parsed `Value` as a `*big.Float` to maintain precision
    And it stores the `SrcRange` for the literal in the source.

  Scenario: String Value Node (`stringVal`)
    The `stringVal` node represents a JSON string literal.
    Given a parsed JSON string literal
    Then it is represented internally by a `stringVal` node
    And this node contains the parsed `Value` as a Go string (after unescaping)
    And it stores the `SrcRange` for the literal in the source (including quotes).

  Scenario: Null Value Node (`nullVal`)
    The `nullVal` node represents a JSON null literal.
    Given a parsed JSON `null` literal
    Then it is represented internally by a `nullVal` node
    And it stores the `SrcRange` for the literal in the source.

  Scenario: Invalid Value Node (`invalidVal`)
    The `invalidVal` node is a placeholder used in the AST.
    Given a situation where the parser encounters an invalid sequence but needs to construct a syntactically complete parent node
    Then an `invalidVal` node may be used to represent the problematic part
    And this node stores the `SrcRange` of the invalid portion.
    # Its primary purpose is to allow the parser to recover and continue,
    # with errors being reported as diagnostics.
```
