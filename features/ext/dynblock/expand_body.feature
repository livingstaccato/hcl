# Covers tests in ./ext/dynblock/expand_body_test.go
# Specifically, TestExpand, TestExpandWithForEachCheck, TestExpandUnknownBodies, TestExpandMarkedForEach, TestExpandInvalidIteratorError

Feature: Dynamic Block Expansion
  This feature tests the expansion of `dynamic` blocks within an HCL body,
  covering various scenarios including nested dynamic blocks, different iterator
  names, label generation, handling of unknown `for_each` collections,
  custom `for_each` checks, and error conditions.

  Background:
    Given an HCL body that may contain `dynamic` blocks.
    And `dynamic` blocks have `for_each`, optional `iterator`, optional `labels`, and a `content` block.

  Scenario: Expanding a complex body with nested static and dynamic blocks
    Given an HCL body with a mix of static 'a' blocks, static 'b' blocks,
    and `dynamic "a"`, `dynamic "b"`, `dynamic "c"` blocks with various nesting levels.
    And the `dynamic "a"` block iterates over `["dynamic a 0", "dynamic a 1", "dynamic a 2"]` using iterator `a`, generating labels from `a.key`.
    And one `dynamic "b"` block (inside a static 'b') iterates over `["dynamic c 0", "dynamic c 1"]` using iterator `dyn_c`.
    And another `dynamic "b"` block (top-level) iterates over `["dynamic b 0", "dynamic b 1"]` using iterator `dyn_b`, containing:
      - A static 'c' block.
      - A `dynamic "c"` block iterating over `["dynamic c 2", "dynamic c 3"]` using default iterator `c`.
    And a third `dynamic "b"` block (top-level) iterates over a map `{"foo": ["dynamic c nested 0", "dynamic c nested 1"]}` using iterator `dyn_b`, containing:
      - A nested `dynamic "c"` block iterating over `dyn_b.value` using default iterator `c`.
    When the body is expanded
    And then partially decoded for 'a' blocks (map with key "key" and string "val")
    Then the decoded 'a' blocks should be a map:
      | key       | val           |
      | "static0" | "static a 0"  |
      | "static1" | "static a 1"  |
      | "0"       | "dynamic a 0" |
      | "1"       | "dynamic a 1" |
      | "2"       | "dynamic a 2" |
    And no diagnostics should be reported for 'a' block decoding
    When the remaining body is decoded for 'b' blocks (list of 'c' blocks, where 'c' is list of objects with "val0", "val1" strings)
    Then the decoded 'b' blocks result should be a list containing:
      - A list for the first 'b' block:
        | val0          | val1          |
        | "static c 0"  | (null)        |
        | "dynamic c 0" | (null)        |
        | "dynamic c 1" | (null)        |
      - A list for the second 'b' block, first iteration ("dynamic b 0"):
        | val0          | val1          |
        | "static c 1"  | "dynamic b 0" |
        | "dynamic c 2" | "dynamic b 0" |
        | "dynamic c 3" | "dynamic b 0" |
      - A list for the second 'b' block, second iteration ("dynamic b 1"):
        | val0          | val1          |
        | "static c 1"  | "dynamic b 1" |
        | "dynamic c 2" | "dynamic b 1" |
        | "dynamic c 3" | "dynamic b 1" |
      - A list for the third 'b' block, only iteration ("foo"):
        | val0                   | val1  |
        | "dynamic c nested 0"   | "foo" |
        | "dynamic c nested 1"   | "foo" |
    And no diagnostics should be reported for 'b' block decoding

  Scenario: Expanding with a custom for_each check that returns an error
    Given an HCL body with a `dynamic "foo"` block
    And its `for_each` expression evaluates to an empty map marked "boop"
    And an evaluation context
    And an OptCheckForEach hook is provided that:
      - Sets a flag indicating it was called
      - Captures the evaluated `for_each` value and the EvalContext
      - Returns a diagnostic with Severity Error, Summary "Bad for_each", Detail "I don't like it.", and Extra "diagnostic extra"
    When the body is expanded with this hook
    And the content of the expanded body is requested for schema `block "foo"`
    Then diagnostics should be reported
    And there should be 1 diagnostic
    And the diagnostic summary should be "Bad for_each"
    And the diagnostic detail should be "I don't like it."
    And the diagnostic extra data should be "diagnostic extra"
    And the for_each check hook should have been called
    And the value passed to the hook should be the empty map marked "boop"
    And the EvalContext passed to the hook should be the original evaluation context

  Scenario Outline: Expanding dynamic blocks with unknown for_each collections
    Given an HCL body with a `dynamic "<block_type>"` block
    And its `for_each` expression evaluates to cty.UnknownVal(cty.Map(cty.String))
    And its `content` block defines an attribute "val" from `each.value`
    And if "<block_type>" is "map" or "object", its `labels` attribute is `["static"]`
    When the body is expanded
    And then partially decoded for "<block_type>" blocks using spec <decoding_spec>
    Then no decoding diagnostics should be reported (unless specified otherwise)
    And the decoded value should be <expected_value>

    Examples:
      | block_type    | decoding_spec                                                                      | expected_value                                                              |
      | list          | BlockListSpec, Nested: ObjectSpec with "val": AttrSpec(String)                     | cty.UnknownVal(cty.List(cty.Object({"val": cty.String})))                    |
      | tuple         | BlockTupleSpec, Nested: ObjectSpec with "val": AttrSpec(String)                    | cty.DynamicVal                                                              |
      | set           | BlockSetSpec, Nested: ObjectSpec with "val": AttrSpec(String)                      | cty.UnknownVal(cty.Set(cty.Object({"val": cty.String})))                     |
      | map           | BlockMapSpec, LabelNames:["key"], Nested: ObjectSpec with "val": AttrSpec(String)  | cty.UnknownVal(cty.Map(cty.Object({"val": cty.String})))                     |
      | object        | BlockObjectSpec, LabelNames:["key"], Nested: ObjectSpec with "val": AttrSpec(String)| cty.UnknownVal(cty.Map(cty.Object({"val": cty.String}))) # BlockObjectSpec decodes to map-like |

  Scenario: Expanding dynamic block with unknown for_each and extraneous attribute in content
    Given an HCL body with a `dynamic "invalid_list"` block
    And its `for_each` expression evaluates to cty.UnknownVal(cty.Map(cty.String))
    And its `content` block defines attributes "val" from `each.value` and an extraneous attribute "invalid"
    When the body is expanded
    And then partially decoded for "invalid_list" blocks using a BlockListSpec for "val"
    Then 1 diagnostic should be reported
    And the diagnostic message should contain 'Mock body has extraneous argument "invalid"'

  Scenario: Expanding dynamic blocks with a marked for_each collection
    Given an HCL body with a `dynamic "b"` block
    And its `for_each` expression evaluates to `["hey"]` (tuple) marked "boop"
    And its `iterator` is `dyn_b`
    And its `content` block defines attributes "val0" as literal "static c 1" and "val1" from `dyn_b.value`
    When the body is expanded
    And then decoded for "b" blocks (BlockListSpec, Nested: ObjectSpec with "val0":String, "val1":String)
    Then no decoding diagnostics should be reported
    And the decoded value should be a list containing one object:
      | val0           | val1        | (marks) |
      | "static c 1"   | "hey"       | "boop"  |
    And the outer object itself should also be marked "boop"

  Scenario: Expanding dynamic block with an invalid iterator expression
    Given an HCL body with a `dynamic "b"` block
    And its `for_each` is `["dynamic b 0", "dynamic b 1"]`
    And its `iterator` attribute is a literal string "dyn_b" (not a variable reference)
    And its `content` block attempts to use `dyn_b.value`
    When the body is expanded
    And then decoded for "b" blocks (BlockListSpec, Nested: BlockListSpec "c", Nested ObjectSpec)
    Then at least 1 diagnostic should be reported
    And the first diagnostic summary should be "Invalid expression"
