# Covers tests in ./hcldec/public_test.go
# Specifically, TestDecode and TestSourceRange

Feature: HCL Decoding Public API
  This feature covers the public API for HCL decoding, primarily the Decode function and SourceRange function.

  Scenario Outline: Decode Function - Various Specs and Inputs
    Given the HCL config:
      """
      <config>
      """
    And the HCL decoding spec: <spec_type>
    And the evaluation context is <eval_context>
    When the config is decoded
    Then the resulting cty.Value should be <expected_value>
    And the number of diagnostics should be <diag_count>

    Examples:
      | config    | spec_type                                                                 | eval_context | expected_value                                       | diag_count |
      |           | ObjectSpec                                                                | nil          | {}                                                   | 0          |
      | a = 1     | ObjectSpec                                                                | nil          | {}                                                   | 1          |
      | a = 1     | ObjectSpec with "a": AttrSpec(Number)                                     | nil          | {"a": 1}                                             | 0          |
      | a = 1     | AttrSpec "a" (Number)                                                     | nil          | 1                                                    | 0          |
      | a = 1     | DefaultSpec Primary: AttrSpec "a" (Number), Default: LiteralSpec(10)      | nil          | 1                                                    | 0          |
      |           | DefaultSpec Primary: AttrSpec "a" (Number), Default: LiteralSpec(10)      | nil          | 10                                                   | 0          |
      | a = 1     | ObjectSpec with "foo": DefaultSpec(Primary: AttrSpec "a", Default: 10)    | nil          | {"foo": 1}                                           | 0          |
      | a = "1"   | AttrSpec "a" (Number)                                                     | nil          | 1                                                    | 0          |
      | a = true  | AttrSpec "a" (Number)                                                     | nil          | (unknown Number)                                     | 1          |
      |           | AttrSpec "a" (Number, Required)                                           | nil          | (null Number)                                        | 1          |
      |           | AttrSpec "a" (ObjectWithOptionalAttrs {"attr": String})                   | nil          | (null Object{"attr": String})                         | 0          |
      | b {}      | BlockSpec "b", Nested: ObjectSpec                                         | nil          | {}                                                   | 0          |
      | b "baz" {}| BlockSpec "b", Nested: BlockLabelSpec(Index:0, Name:"name")               | nil          | "baz"                                                | 0          |
      | b "baz" {}\nb "foo" {} | BlockSpec "b", Nested: BlockLabelSpec(Index:0, Name:"name")  | nil          | "baz"                                                | 1          |
      | b {}      | BlockSpec "b", Nested: BlockLabelSpec(Index:0, Name:"name")               | nil          | (null String)                                        | 1          |
      |           | BlockSpec "b", Nested: ObjectSpec                                         | nil          | (null {})                                            | 0          |
      | a {}      | BlockSpec "b", Nested: ObjectSpec                                         | nil          | (null {})                                            | 1          |
      |           | BlockSpec "b", Nested: ObjectSpec, Required                               | nil          | (null {})                                            | 1          |
      | b {}\nb {} | BlockSpec "b", Nested: ObjectSpec, Required                               | nil          | {}                                                   | 1          |
      | b {}      | BlockAttrsSpec "b", ElementType: String                                   | nil          | (map String -> {})                                   | 0          |
      | b {\n  hello = "world"\n} | BlockAttrsSpec "b", ElementType: String                    | nil          | {"hello": "world"}                                   | 0          |
      | b {\n  hello = true\n}   | BlockAttrsSpec "b", ElementType: String                    | nil          | {"hello": "true"}                                    | 0          |
      | b {\n  hello = true\n  goodbye = 5\n} | BlockAttrsSpec "b", ElementType: String        | nil          | {"hello": "true", "goodbye": "5"}                    | 0          |
      |           | BlockAttrsSpec "b", ElementType: String                                   | nil          | (null map[string]string)                             | 0          |
      |           | BlockAttrsSpec "b", ElementType: String, Required                         | nil          | (null map[string]string)                             | 1          |
      |           | BlockAttrsSpec "b", ElementType: ObjectWithOptionalAttrs {"attr": String} | nil          | (null map[string]Object{"attr": String})             | 0          |
      | b {}\nb {} | BlockAttrsSpec "b", ElementType: String                                   | nil          | (map String -> {})                                   | 1          |
      | b {}\nb {} | BlockAttrsSpec "b", ElementType: String, Required                         | nil          | (map String -> {})                                   | 1          |
      | b {}\nb {} | BlockListSpec "b", Nested: ObjectSpec                                     | nil          | [{}, {}]                                             | 0          |
      |           | BlockListSpec "b", Nested: ObjectSpec                                     | nil          | []                                                   | 0          |
      | b "foo" {}\nb "bar" {} | BlockListSpec "b", Nested: BlockLabelSpec(Name:"name", Index:0) | nil      | ["foo", "bar"]                                       | 0          |
      | b {}\nb {}\nb {}       | BlockListSpec "b", Nested: ObjectSpec, MaxItems: 2          | nil          | [{}, {}, {}]                                         | 1          |
      | b {}\nb {}             | BlockListSpec "b", Nested: ObjectSpec, MinItems: 10         | nil          | [{}, {}]                                             | 1          |
      | b {\n a = true\n}\nb {\n a = 1\n} | BlockListSpec "b", Nested: AttrSpec "a" (Dynamic) | nil          | (dynamic)                                            | 1          |
      | b {\n a = true\n}\nb {\n a = "not a bool"\n} | BlockListSpec "b", Nested: AttrSpec "a" (Dynamic) | nil | ["true", "not a bool"]                             | 0          |
      | b {}\nb {} | BlockSetSpec "b", Nested: ObjectSpec, MaxItems: 2                         | nil          | { {}, {} }                                           | 0          |
      | b "foo" "bar" {}\nb "bar" "baz" {} | BlockSetSpec "b", Nested: TupleSpec(BlockLabelSpec "name" @1, BlockLabelSpec "type" @0) | nil | {("bar", "foo"), ("baz", "bar")}                  | 0          |
      | b {\n a = true\n}\nb {\n a = 1\n} | BlockSetSpec "b", Nested: AttrSpec "a" (Dynamic)  | nil          | (dynamic)                                            | 1          |
      | b {\n a = true\n}\nb {\n a = "not a bool"\n} | BlockSetSpec "b", Nested: AttrSpec "a" (Dynamic) | nil | {"true", "not a bool"}                             | 0          |
      | b "foo" {}\nb "bar" {} | BlockMapSpec "b", LabelNames: ["key"], Nested: ObjectSpec     | nil          | {"foo": {}, "bar": {}}                               | 0          |
      | b "foo" "bar" {}\nb "bar" "baz" {} | BlockMapSpec "b", LabelNames: ["key1", "key2"], Nested: ObjectSpec | nil | {"foo": {"bar": {}}, "bar": {"baz": {}}}         | 0          |
      | b "foo" "bar" {}\nb "foo" "baz" {} | BlockMapSpec "b", LabelNames: ["key1", "key2"], Nested: ObjectSpec | nil | {"foo": {"bar": {}, "baz": {}}}                   | 0          |
      | b "foo" "bar" {}        | BlockMapSpec "b", LabelNames: ["key"], Nested: ObjectSpec     | nil          | {}                                                   | 1          |
      | b "bar" {}              | BlockMapSpec "b", LabelNames: ["key1", "key2"], Nested: ObjectSpec | nil      | {}                                                   | 1          |
      | b "foo" {}\nb "foo" {} | BlockMapSpec "b", LabelNames: ["key"], Nested: ObjectSpec     | nil          | {"foo": {}}                                          | 1          |
      | b "foo" "bar" {}\nb "foo" "bar" {} | BlockMapSpec "b", LabelNames: ["key1", "key2"], Nested: ObjectSpec | nil | {"foo": {"bar": {}}}                             | 1          |
      | b "foo" "bar" {}\nb "bar" "baz" {} | BlockMapSpec "b", LabelNames: ["type"], Nested: BlockLabelSpec(Name:"name", Index:0) | nil | {"foo": "bar", "bar": "baz"}                   | 0          |
      | b "foo" {}              | BlockMapSpec "b", LabelNames: ["type"], Nested: BlockLabelSpec(Name:"name", Index:0) | nil | (map string -> {})                               | 1          |
      | b {}\nb {} | BlockTupleSpec "b", Nested: ObjectSpec                                    | nil          | [{}, {}]                                             | 0          |
      |           | BlockTupleSpec "b", Nested: ObjectSpec                                    | nil          | []                                                   | 0          |
      | b "foo" {}\nb "bar" {} | BlockTupleSpec "b", Nested: BlockLabelSpec(Name:"name", Index:0)| nil         | ["foo", "bar"]                                       | 0          |
      | b {}\nb {}\nb {}       | BlockTupleSpec "b", Nested: ObjectSpec, MaxItems: 2         | nil          | [{}, {}, {}]                                         | 1          |
      | b {}\nb {}             | BlockTupleSpec "b", Nested: ObjectSpec, MinItems: 10        | nil          | [{}, {}]                                             | 1          |
      | b {\n a = true\n}\nb {\n a = 1\n} | BlockTupleSpec "b", Nested: AttrSpec "a" (Dynamic)| nil          | [true, 1]                                            | 0          |
      | b {\n a = true\n}\nb {\n a = "not a bool"\n} | BlockTupleSpec "b", Nested: AttrSpec "a" (Dynamic)| nil | [true, "not a bool"]                               | 0          |
      | b "foo" {}\nb "bar" {} | BlockObjectSpec "b", LabelNames: ["key"], Nested: ObjectSpec  | nil          | {"foo": {}, "bar": {}}                               | 0          |
      | b "foo" "bar" {}\nb "bar" "baz" {} | BlockObjectSpec "b", LabelNames: ["key1", "key2"], Nested: ObjectSpec | nil | {"foo": {"bar": {}}, "bar": {"baz": {}}}         | 0          |
      | b "foo" "bar" {}\nb "foo" "baz" {} | BlockObjectSpec "b", LabelNames: ["key1", "key2"], Nested: ObjectSpec | nil | {"foo": {"bar": {}, "baz": {}}}                   | 0          |
      | b "foo" "bar" {}        | BlockObjectSpec "b", LabelNames: ["key"], Nested: ObjectSpec  | nil          | {}                                                   | 1          |
      | b "bar" {}              | BlockObjectSpec "b", LabelNames: ["key1", "key2"], Nested: ObjectSpec | nil      | {}                                                   | 1          |
      | b "foo" {}\nb "foo" {} | BlockObjectSpec "b", LabelNames: ["key"], Nested: ObjectSpec  | nil          | {"foo": {}}                                          | 1          |
      | b "foo" "bar" {}\nb "foo" "bar" {} | BlockObjectSpec "b", LabelNames: ["key1", "key2"], Nested: ObjectSpec | nil | {"foo": {"bar": {}}}                             | 1          |
      | b "foo" "bar" {}\nb "bar" "baz" {} | BlockObjectSpec "b", LabelNames: ["type"], Nested: BlockLabelSpec(Name:"name", Index:0) | nil | {"foo": "bar", "bar": "baz"}                   | 0          |
      | b "foo" {}              | BlockObjectSpec "b", LabelNames: ["type"], Nested: BlockLabelSpec(Name:"name", Index:0) | nil | {}                                                   | 1          |
      | b "foo" {\n arg = true\n}\nb "bar" {\n arg = 1\n} | BlockObjectSpec "b", LabelNames: ["type"], Nested: AttrSpec "arg" (Dynamic) | nil | {"foo": true, "bar": 1} | 0          |

  Scenario Outline: SourceRange Function
    Given the HCL config:
      """
      <config>
      """
    And the HCL decoding spec: <spec_type>
    When the source range is retrieved
    Then the resulting range should be <expected_range>

    Examples:
      | config                     | spec_type                                                              | expected_range                     |
      | a = 1                      | AttrSpec "a"                                                           | L1C5-L1C6 (B4-B5)                  |
      | b {\n  a = 1\n}            | BlockSpec "b", Nested: AttrSpec "a"                                    | L3C7-L3C8 (B11-B12)                |
      | b {\n  c {\n    a = 1\n  }\n} | BlockSpec "b", Nested: BlockSpec "c", Nested: AttrSpec "a"           | L4C9-L4C10 (B19-B20)               |
