# Covers functions in ./hcldec/public.go
# Based on test cases in ./hcldec/public_test.go (primarily TestDecode, TestSourceRange)
# Also includes new scenarios for PartialDecode and ChildBlockTypes based on public.go API.

Feature: HCLDec Public API - Decoding and Inspecting Specs
  This feature tests the main public functions of the `hcldec` package,
  including decoding HCL bodies with various specifications, partial decoding,
  and inspecting specifications for implied types, source ranges, and child block types.

  Scenario Outline: Decode Function - Full decoding with various specs and inputs
    Given the HCL config:
      """
      <config_hcl>
      """
    And the HCL decoding spec: <spec_description>
    And an evaluation context <eval_context_setup>
    When the config is decoded using `hcldec.Decode`
    Then the resulting cty.Value should be <expected_cty_value>
    And the number of diagnostics should be <expected_diag_count>

    Examples:
      # ObjectSpec examples
      | config_hcl | spec_description                                      | eval_context_setup | expected_cty_value                               | expected_diag_count |
      | ``         | ObjectSpec {}                                         | (nil)              | EmptyObjectVal                                   | 0                   |
      | `a = 1\n`  | ObjectSpec {}                                         | (nil)              | EmptyObjectVal                                   | 1                   | # "a" not expected
      | `a = 1\n`  | ObjectSpec {"a": AttrSpec(Name:"a", Type:Number)}     | (nil)              | ObjectVal({"a": NumberIntVal(1)})                | 0                   |
      # AttrSpec examples
      | `a = 1\n`  | AttrSpec(Name:"a", Type:Number)                       | (nil)              | NumberIntVal(1)                                  | 0                   |
      | `a = "1"\n`| AttrSpec(Name:"a", Type:Number)                       | (nil)              | NumberIntVal(1)                                  | 0                   | # Type conversion
      | `a = true\n`| AttrSpec(Name:"a", Type:Number)                      | (nil)              | UnknownVal(Number)                               | 1                   | # Incorrect type
      | ``         | AttrSpec(Name:"a", Type:Number, Required:true)        | (nil)              | NullVal(Number)                                  | 1                   | # Required attr missing
      | ``         | AttrSpec(Name:"a", Type:ObjOptAttrs({"attr":Str})) | (nil)              | NullVal(Object({"attr":String}))                 | 0                   | # Optional object attr
      # DefaultSpec examples
      | `a = 1\n`  | DefaultSpec(Primary:AttrSpec("a",Num), Default:Lit(Num(10))) | (nil)   | NumberIntVal(1)                                  | 0                   |
      | ``         | DefaultSpec(Primary:AttrSpec("a",Num), Default:Lit(Num(10))) | (nil)   | NumberIntVal(10)                                 | 0                   |
      # BlockSpec examples
      | `b {}\n`   | BlockSpec(Type:"b", Nested:ObjSpec{})                 | (nil)              | EmptyObjectVal                                   | 0                   |
      | `b "lbl" {}\n`| BlockSpec(Type:"b", Nested:BlockLabelSpec(Idx:0,Name:"name"))| (nil)  | StringVal("lbl")                                 | 0                   |
      | `b "l1"{}\nb "l2"{}\n`| BlockSpec(Type:"b",Nested:BlockLabelSpec(Idx:0,Name:"name"))| (nil)| StringVal("l1")                                | 1                   | # Duplicate block for BlockSpec
      | `b {}\n`   | BlockSpec(Type:"b",Nested:BlockLabelSpec(Idx:0,Name:"name"))| (nil)      | NullVal(String)                                  | 1                   | # Missing label
      | ``         | BlockSpec(Type:"b",Nested:ObjSpec{},Required:true)    | (nil)              | NullVal(EmptyObject)                             | 1                   | # Required block missing
      # BlockAttrsSpec examples
      | `b {h="w"}\n`| BlockAttrsSpec(Type:"b", ElemType:String)           | (nil)              | MapVal({"h":StringVal("w")})                     | 0                   |
      | `b {h=true}\n`| BlockAttrsSpec(Type:"b", ElemType:String)          | (nil)              | MapVal({"h":StringVal("true")})                  | 0                   | # Type conversion in BlockAttrs
      | ``         | BlockAttrsSpec(Type:"b", ElemType:Str, Req:true)      | (nil)              | NullVal(Map(String))                             | 1                   | # Required BlockAttrs missing
      # BlockListSpec examples
      | `b {}\nb {}\n`| BlockListSpec(Type:"b",Nested:ObjSpec{})            | (nil)              | ListVal([EmptyObjectVal, EmptyObjectVal])        | 0                   |
      | `b {}\nb {}\nb {}\n`| BlockListSpec(Type:"b",Nested:ObjSpec{},Max:2) | (nil)            | ListVal([EOV,EOV,EOV])                           | 1                   | # Too many blocks
      | `b {a=true}\nb {a=1}\n`| BlockListSpec(Type:"b",Nested:AttrSpec("a",Dyn))| (nil)         | DynamicVal                                       | 1                   | # Inconsistent types in list
      # BlockSetSpec examples
      | `b {}\nb {}\n`| BlockSetSpec(Type:"b",Nested:ObjSpec{},Max:2)      | (nil)              | SetVal([EmptyObjectVal])                         | 0                   | # Set collapses duplicates
      # BlockMapSpec examples
      | `b "k1"{}\nb "k2"{}\n`| BlockMapSpec(Type:"b",Labels:["key"],Nested:ObjSpec{})| (nil)    | MapVal({"k1":EOV,"k2":EOV})                      | 0                   |
      | `b "k1"{}\nb "k1"{}\n`| BlockMapSpec(Type:"b",Labels:["key"],Nested:ObjSpec{})| (nil)    | MapVal({"k1":EOV})                               | 1                   | # Duplicate key for map
      # BlockTupleSpec examples
      | `b {a=true}\nb {a=1}\n`| BlockTupleSpec(Type:"b",Nested:AttrSpec("a",Dyn))| (nil)       | TupleVal([True, NumberIntVal(1)])                | 0                   | # Tuple allows different types
      # BlockObjectSpec examples
      | `b "k1"{a=true}\nb "k2"{a=1}\n`| BlockObjectSpec(Type:"b",Labels:["key"],Nested:AttrSpec("a",Dyn))| (nil)| ObjectVal({"k1":True,"k2":NumberIntVal(1)}) | 0                   |


  Scenario Outline: SourceRange Function - Retrieving source range for specified parts of HCL
    Given the HCL config:
      """
      <config_hcl>
      """
    And the HCL decoding spec: <spec_description>
    When `hcldec.SourceRange` is called for the body and spec
    Then the resulting hcl.Range should be Start:<start_pos_str> End:<end_pos_str>

    Examples:
      | config_hcl                 | spec_description                                     | start_pos_str     | end_pos_str       |
      | `a = 1\n`                  | AttrSpec(Name:"a")                                   | L1C5B4            | L1C6B5            |
      | `\nb {\n  a = 1\n}\n`      | BlockSpec(Type:"b", Nested:AttrSpec(Name:"a"))       | L3C7B11           | L3C8B12           |
      | `\nb {\n  c {\n    a = 1\n  }\n}\n` | BlockSpec(Type:"b",Nested:BlockSpec(Type:"c",Nested:AttrSpec(Name:"a"))) | L4C9B19 | L4C10B20          |

  Scenario: PartialDecode with leftover attributes
    Given an HCL body parsed from `attr1 = "v1"\nattr2 = "v2"\n`
    And a Spec `ObjectSpec{"attr1": AttrSpec(Name:"attr1", Type:String)}`
    When `hcldec.PartialDecode` is called with the body, spec, and nil context
    Then the decoded cty.Value should be `ObjectVal({"attr1":StringVal("v1")})`
    And the 'leftover' hcl.Body when its attributes are requested using `JustAttributes` should yield `{"attr2": Attr(Name:"attr2", ...)}`
    And no diagnostics should be reported

  Scenario: PartialDecode with leftover blocks
    Given an HCL body parsed from `block_one {}\nblock_two {}\n`
    And a Spec `ObjectSpec{"block_one": BlockSpec(TypeName:"block_one", Nested:ObjectSpec{})}`
    When `hcldec.PartialDecode` is called with the body, spec, and nil context
    Then the decoded cty.Value should be `ObjectVal({"block_one":EmptyObjectVal})`
    And the 'leftover' hcl.Body when its content is requested with schema for "block_two" should yield one block of type "block_two"
    And no diagnostics should be reported

  Scenario: PartialDecode with no leftovers
    Given an HCL body parsed from `attr1 = "v1"\n`
    And a Spec `ObjectSpec{"attr1": AttrSpec(Name:"attr1", Type:String)}`
    When `hcldec.PartialDecode` is called with the body, spec, and nil context
    Then the decoded cty.Value should be `ObjectVal({"attr1":StringVal("v1")})`
    And the 'leftover' hcl.Body should be effectively empty (e.g., `JustAttributes` yields empty map and no blocks)
    And no diagnostics should be reported

  Scenario: ChildBlockTypes from a complex spec
    Given a Spec defined as:
      ObjectSpec{
        "attr_level_one": AttrSpec(Name:"level_one", Type:String),
        "block_level_one": BlockSpec(TypeName:"one", Nested: ObjectSpec{
          "child_attr": AttrSpec(Name:"child_attr", Type:Number),
          "block_level_two": BlockListSpec(TypeName:"two", Nested: AttrSpec(Name:"list_attr", Type:Bool))
        }),
        "another_block": BlockMapSpec(TypeName:"map_block", LabelNames:["key"], Nested:ObjectSpec{})
      }
    When `hcldec.ChildBlockTypes` is called with this spec
    Then the resulting map of child block specs should contain 3 entries
    And the entry for "one" should be the Nested Spec of the "block_level_one" BlockSpec (an ObjectSpec)
    And the entry for "two" should be the Nested Spec of the "block_level_two" BlockListSpec (an AttrSpec)
    And the entry for "map_block" should be the Nested Spec of the "another_block" BlockMapSpec (an ObjectSpec)

  Scenario: ChildBlockTypes from a spec with no blocks
    Given a Spec defined as `ObjectSpec{"attr": AttrSpec(Name:"attr", Type:String)}`
    When `hcldec.ChildBlockTypes` is called with this spec
    Then the resulting map of child block specs should be empty

    # Notes for table values:
    # - Spec descriptions are simplified. E.g., AttrSpec(Name:"a", Type:Number) or ObjSpec{}.
    # - ObjOptAttrs({"attr":Str}) means cty.ObjectWithOptionalAttrs(map[string]cty.Type{"attr":cty.String}, []string{"attr"}).
    # - Lit(Num(10)) means LiteralSpec{Value: cty.NumberIntVal(10)}.
    # - EOV means cty.EmptyObjectVal. Dyn means cty.DynamicPseudoType.
    # - eval_context_setup: (nil) means nil context.
    # - expected_cty_value: String representation of the cty.Value.
    # - start_pos_str/end_pos_str: LxCxB format (Line, Column, Byte).
    # - Attr(Name:"attr2", ...) implies details of the attribute are checked, simplified here.
