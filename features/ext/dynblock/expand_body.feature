# Covers functionalities in ./ext/dynblock/expand_body.go
# Based on test cases in ./ext/dynblock/expand_body_test.go

Feature: HCL Dynamic Block Expansion
  This feature tests the expansion of `dynamic` blocks within an HCL body.
  Dynamic blocks allow for the generation of multiple HCL blocks based on a
  collection, providing iteration capabilities within HCL configurations.

  Scenario: Expanding a complex body with nested static and dynamic blocks
    Given an HCL body constructed with a mix of static blocks ("a", "b", "c") and dynamic blocks ("dynamic a", "dynamic b", "dynamic c")
      # Details of the mock body structure:
      # - Static "a" block "static0" with val "static a 0"
      # - Static "b" block containing:
      #   - Static "c" block with val0 "static c 0"
      #   - Dynamic "c" block iterating over ["dynamic c 0", "dynamic c 1"] with iterator "dyn_c", content sets val0 from "dyn_c.value"
      # - Dynamic "a" block iterating over ["dynamic a 0", "dynamic a 1", "dynamic a 2"] with iterator "a", labels from "a.key", content sets val from "a.value"
      # - Dynamic "b" block iterating over ["dynamic b 0", "dynamic b 1"] with iterator "dyn_b", content containing:
      #   - Static "c" block with val0 "static c 1" and val1 from "dyn_b.value"
      #   - Dynamic "c" block iterating over ["dynamic c 2", "dynamic c 3"] with iterator "c", content sets val0 from "c.value" and val1 from "dyn_b.value"
      # - Dynamic "b" block iterating over map {"foo": ["dynamic c nested 0", "dynamic c nested 1"]} with iterator "dyn_b", content containing:
      #   - Dynamic "c" block iterating over "dyn_b.value" with iterator "c", content sets val0 from "c.value" and val1 from "dyn_b.key"
      # - Static "a" block "static1" with val "static a 1"
    And a nil evaluation context for expansion
    When the HCL body is expanded using `dynblock.Expand`
    And the expanded body is partially decoded for "a" blocks (BlockMapSpec, key "key", nested AttrSpec "val" String)
    Then no diagnostics should be reported
    And the decoded "a" blocks should be a cty.Map:
      | key       | value_string  |
      | "static0" | "static a 0"  |
      | "static1" | "static a 1"  |
      | "0"       | "dynamic a 0" |
      | "1"       | "dynamic a 1" |
      | "2"       | "dynamic a 2" |
    When the remaining body is decoded for "b" blocks (BlockListSpec, nested BlockListSpec "c", nested ObjectSpec for "val0", "val1" Strings)
    Then no diagnostics should be reported
    And the decoded "b" blocks (a list of lists of objects) should match the complex expected structure from `TestExpand`
      # This includes verification of:
      # - First 'b' block containing one static 'c' and two dynamic 'c's.
      # - Second 'b' block (iterated for "dynamic b 0") containing one static 'c' and two dynamic 'c's, with 'dyn_b.value' correctly interpolated.
      # - Third 'b' block (iterated for "dynamic b 1") similar to the second.
      # - Fourth 'b' block (iterated for map key "foo") containing two dynamic 'c's from the nested list, with 'dyn_b.key' and 'c.value' interpolated.

  Scenario: Expanding with a custom for_each check that returns an error diagnostic
    Given an HCL body with a `dynamic "foo"` block
    And its `for_each` expression evaluates to an empty cty.Map marked "boop"
    And an empty evaluation context
    And a custom `OptCheckForEach` hook that:
      Always returns a diagnostic: Severity Error, Summary "Bad for_each", Detail "I don't like it.", Extra "diagnostic extra"
      And captures the `for_each` value and eval context passed to it
    When the body is expanded with this hook
    And content is requested from the expanded body for a schema expecting block "foo"
    Then 1 diagnostic should be reported
    And the diagnostic Summary should be "Bad for_each"
    And the diagnostic Detail should be "I don't like it."
    And the diagnostic Extra field should be "diagnostic extra"
    And the custom hook should have been called
    And the value passed to the hook should be the empty map marked "boop"
    And the EvalContext passed to the hook should be the original empty context

  Scenario Outline: Expanding dynamic blocks when for_each collection is unknown
    Given an HCL body with a `dynamic "<block_type_name>"` block
    And its `for_each` expression evaluates to `cty.UnknownVal(cty.Map(cty.String))`
    And its `content` block defines an attribute "val" from `each.value`
    And if "<block_type_name>" is "map" or "object", its `labels` attribute is `["static"]` (a list containing one literal string "static")
    When the body is expanded using `dynblock.Expand`
    And the expanded body is partially decoded for "<block_type_name>" blocks using spec <decoding_spec_description>
    Then no decoding diagnostics should be reported
    And the decoded cty.Value should be <expected_cty_value>

    Examples:
      | block_type_name | decoding_spec_description                                                                 | expected_cty_value                                                            |
      | list            | BlockListSpec, Nested: ObjectSpec with "val": AttrSpec(String)                            | `cty.UnknownVal(cty.List(cty.Object({"val": cty.String})))`                   |
      | tuple           | BlockTupleSpec, Nested: ObjectSpec with "val": AttrSpec(String)                           | `cty.DynamicVal`                                                              |
      | set             | BlockSetSpec, TypeName:"tuple", Nested: ObjectSpec with "val": AttrSpec(String)           | `cty.UnknownVal(cty.Set(cty.Object({"val": cty.String})))`                   | # TypeName in spec is "tuple" in Go test
      | map             | BlockMapSpec, TypeName:"map", LabelNames:["key"], Nested:ObjectSpec{"val":AttrSpec(Str)} | `cty.UnknownVal(cty.Map(cty.Object({"val": cty.String})))`                   |
      | object          | BlockObjectSpec, TypeName:"object", LabelNames:["key"], Nested:ObjectSpec{"val":AttrSpec(Str)}| `cty.UnknownVal(cty.Map(cty.Object({"val": cty.String})))` # BlockObjectSpec results in map-like cty.Map |

  Scenario: Expanding dynamic block with unknown for_each and extraneous attribute in content
    Given an HCL body with a `dynamic "invalid_list"` block
    And its `for_each` expression evaluates to `cty.UnknownVal(cty.Map(cty.String))`
    And its `content` block defines attribute "val" from `each.value` and an extraneous attribute "invalid" = "static"
    When the body is expanded using `dynblock.Expand`
    And the expanded body is partially decoded for "invalid_list" blocks (BlockListSpec, Nested: ObjectSpec with "val": AttrSpec(String))
    Then 1 diagnostic should be reported
    And the diagnostic message should contain 'Mock body has extraneous argument "invalid"'

  Scenario: Expanding dynamic block with a marked for_each collection
    Given an HCL body with a `dynamic "b"` block
    And its `for_each` expression evaluates to `cty.TupleVal([StringVal("hey")])` marked "boop"
    And its `iterator` expression evaluates to variable "dyn_b"
    And its `content` block defines attributes "val0" as literal "static c 1" and "val1" from `dyn_b.value`
    When the body is expanded using `dynblock.Expand`
    And the expanded body is decoded using `hcldec.Decode` for "b" blocks (BlockListSpec, Nested: ObjectSpec "val0":String, "val1":String)
    Then no decoding diagnostics should be reported
    And the decoded cty.Value should be a List containing one Object:
      | val0_val          | val1_val      | object_marks | val0_marks | val1_marks |
      | StringVal("static c 1") | StringVal("hey") | ["boop"]     | ["boop"]   | ["boop"]   |

  Scenario: Expanding dynamic block with an invalid iterator expression
    Given an HCL body with a `dynamic "b"` block
    And its `for_each` expression evaluates to `ListVal([StringVal("dynamic b 0")])`
    And its `iterator` attribute is a literal string "dyn_b" (not a variable reference)
    And its `content` block attempts to use `dyn_b.value`
    When the body is expanded using `dynblock.Expand`
    And the expanded body is decoded using `hcldec.Decode` (BlockListSpec "b", nested BlockListSpec "c", nested ObjectSpec)
    Then at least 1 diagnostic should be reported
    And the first diagnostic Summary should be "Invalid expression" (related to iterator)

    # Notes for table values:
    # - cty.Value representations are simplified (e.g., `["val"]` for ListVal, `{"k":"v"}` for MapVal/ObjectVal).
    # - `EOV` means `cty.EmptyObjectVal`. `Str` means `cty.String`. `Dyn` means `cty.DynamicPseudoType`.
    # - The complex expected structure for the first scenario is detailed in the Go test `TestExpand`.
    # - For marked values, `["mark"]` indicates the set of marks on the value.
