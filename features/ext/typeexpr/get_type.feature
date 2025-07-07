# Covers tests in ./ext/typeexpr/get_type_test.go
# Specifically, TestGetType, TestGetTypeJSON, and TestGetTypeDefaults

Feature: HCL Type Expression Parsing and Default Value Extraction
  This feature tests the parsing of HCL type expressions (like `string`, `list(number)`, `object({name=string})`)
  into cty.Type values, including handling of the `any` keyword, type constructors,
  the `optional` modifier for object attributes, and extraction of default values.
  It covers both native HCL syntax and JSON representation of type expressions.

  Scenario Outline: Parsing HCL type expressions (Native Syntax)
    Given the HCL type expression source: "<source>"
    And the 'is_constraint' flag is <is_constraint>
    When the expression is parsed to get a cty.Type
    Then the resulting cty.Type should be <expected_type_cty>
    And if an error is expected, its detail message should be "<expected_error_detail>"
    And if no error is expected, no error diagnostics should be reported

    Examples:
      # Keywords
      | source   | is_constraint | expected_type_cty     | expected_error_detail                                                                          |
      | bool     | false         | Bool                  |                                                                                                |
      | number   | false         | Number                |                                                                                                |
      | string   | false         | String                |                                                                                                |
      | any      | false         | DynamicPseudoType     | The keyword "any" cannot be used in this type specification: an exact type is required.        |
      | any      | true          | DynamicPseudoType     |                                                                                                |
      # Keyword constructors (invalid uses)
      | list     | false         | DynamicPseudoType     | The list type constructor requires one argument specifying the element type.                 |
      | map      | false         | DynamicPseudoType     | The map type constructor requires one argument specifying the element type.                  |
      | set      | false         | DynamicPseudoType     | The set type constructor requires one argument specifying the element type.                  |
      | object   | false         | DynamicPseudoType     | The object type constructor requires one argument specifying the attribute types and values as a map. |
      | tuple    | false         | DynamicPseudoType     | The tuple type constructor requires one argument specifying the element types as a list.       |
      # Primitive type keywords with unexpected arguments
      | bool()   | false         | DynamicPseudoType     | Primitive type keyword "bool" does not expect arguments.                                     |
      | number() | false         | DynamicPseudoType     | Primitive type keyword "number" does not expect arguments.                                   |
      | string() | false         | DynamicPseudoType     | Primitive type keyword "string" does not expect arguments.                                   |
      | any()    | true          | DynamicPseudoType     | Type constraint keyword "any" does not expect arguments.                                     |
      # Valid constructors
      | list(string)           | false         | List(String)          |                                                                                                |
      | set(string)            | false         | Set(String)           |                                                                                                |
      | map(string)            | false         | Map(String)           |                                                                                                |
      | object({})             | false         | EmptyObject           |                                                                                                |
      | object({name=string})  | false         | Object({name=String}) |                                                                                                |
      | tuple([])              | false         | EmptyTuple            |                                                                                                |
      | tuple([string, bool])  | false         | Tuple([String, Bool]) |                                                                                                |
      # Constructor argument count/type errors
      | list()                 | false         | DynamicPseudoType     | The list type constructor requires one argument specifying the element type.                 |
      | list(string, string)   | false         | DynamicPseudoType     | The list type constructor requires one argument specifying the element type.                 |
      | object()               | false         | DynamicPseudoType     | The object type constructor requires one argument specifying the attribute types and values as a map. |
      | object(string)         | false         | DynamicPseudoType     | Object type constructor requires a map whose keys are attribute names and whose values are the corresponding attribute types. |
      | tuple()                | false         | DynamicPseudoType     | The tuple type constructor requires one argument specifying the element types as a list.       |
      | tuple(string)          | false         | DynamicPseudoType     | Tuple type constructor requires a list of element types.                                     |
      # Invalid keyword/constructor usage
      | object({"name"=string})| false         | EmptyObject           | Object constructor map keys must be attribute names.                                           |
      | object({name=nope})    | false         | Object({name=DynamicPseudoType}) | The keyword "nope" is not a valid type specification.                                     |
      | tuple([nope])          | false         | Tuple([DynamicPseudoType]) | The keyword "nope" is not a valid type specification.                                     |
      | shwoop(string)         | false         | DynamicPseudoType     | Keyword "shwoop" is not a valid type constructor.                                            |
      | list("string")         | false         | List(DynamicPseudoType) | A type specification is either a primitive type keyword (bool, number, string) or a complex type constructor call, like list(string). |
      # Nested constructors
      | list(object({}))       | false         | List(EmptyObject)     |                                                                                                |
      | list(map(tuple([])))   | false         | List(Map(EmptyTuple)) |                                                                                                |
      # Optional modifier
      | object({name=string,age=optional(number)}) | true  | ObjectWithOptionalAttrs({name=String, age=Number}, ["age"]) |                                         |
      | object({name=string,meta=optional(any)})   | true  | ObjectWithOptionalAttrs({name=String, meta=DynamicPseudoType}, ["meta"]) |                               |
      | object({name=string,age=optional(number)}) | false | Object({name=String, age=Number}) | Optional attribute modifier is only for type constraints, not for exact types.             |
      | object({name=string,meta=optional()})      | true  | Object({name=String})             | Optional attribute modifier requires the attribute type as its argument.                   |
      | object({name=string,meta=optional(string, "hello")}) | true | Object({name=String, meta=String}) | Optional attribute modifier expects only one argument: the attribute type.                 |
      | optional(string)       | false         | DynamicPseudoType                 | Keyword "optional" is valid only as a modifier for object type attributes.                 |
      | optional               | false         | DynamicPseudoType                 | The keyword "optional" is not a valid type specification.                                  |

  Scenario Outline: Parsing HCL type expressions (JSON Syntax)
    Given the JSON HCL type expression source: "<source_json>"
    And the 'is_constraint' flag is <is_constraint>
    When the expression is parsed from JSON and then processed to get a cty.Type
    Then the resulting cty.Type should be <expected_type_cty>
    And if an error is expected, its detail message should be "<expected_error_detail>"
    And if no error is expected, no error diagnostics should be reported

    Examples:
      | source_json        | is_constraint | expected_type_cty | expected_error_detail                                                              |
      | {"expr":"bool"}    | false         | Bool              |                                                                                    |
      | {"expr":"list(bool)"} | false         | List(Bool)        |                                                                                    |
      | {"expr":"list"}    | false         | DynamicPseudoType | The list type constructor requires one argument specifying the element type.     |

  Scenario Outline: Extracting Defaults from HCL type expressions with optional attributes
    Given the HCL type expression source: "<source>"
    And the 'is_constraint' flag is true
    And the 'with_defaults' flag is true
    When the expression is parsed to get a cty.Type and Defaults object
    Then the Defaults object should have type <expected_defaults_type_cty>
    And its DefaultValues map should be <expected_default_values_map>
    And its Children map should be <expected_children_map>
    And if an error is expected, its detail message should be "<expected_error_detail>"
    And if no error is expected, no error diagnostics should be reported

    Examples:
      | source                                                  | expected_defaults_type_cty                                     | expected_default_values_map | expected_children_map                                                                                                | expected_error_detail |
      | bool                                                    | nil                                                            | nil                         | nil                                                                                                                  |                       |
      | object({ a = string, b = optional(number, 5) })         | ObjectWithOptionalAttrs({a=String, b=Number}, ["b"])           | {b: NumberIntVal(5)}        | nil                                                                                                                  |                       |
      | object({ a = optional(object({ b = optional(number, 5) }), {}) }) | ObjectWithOptionalAttrs({a=ObjectWithOptionalAttrs({b=Number},["b"])},["a"]) | {a: ObjectVal({b:NullVal(Number)})} | {a: {Type:ObjectWithOptionalAttrs({b=Number},["b"]), DefaultValues:{b:NumberIntVal(5)}}}                               |                       |
      | map(object({ a = string, b = optional(number, 5) }))    | Map(ObjectWithOptionalAttrs({a=String, b=Number}, ["b"]))      | nil                         | {"": {Type:ObjectWithOptionalAttrs({a=String, b=Number},["b"]), DefaultValues:{b:NumberIntVal(5)}}}                     |                       |
      | list(object({ a = string, b = optional(number, 5) }))   | List(ObjectWithOptionalAttrs({a=String, b=Number}, ["b"]))     | nil                         | {"": {Type:ObjectWithOptionalAttrs({a=String, b=Number},["b"]), DefaultValues:{b:NumberIntVal(5)}}}                     |                       |
      | set(object({ a = string, b = optional(number, 5) }))    | Set(ObjectWithOptionalAttrs({a=String, b=Number}, ["b"]))      | nil                         | {"": {Type:ObjectWithOptionalAttrs({a=String, b=Number},["b"]), DefaultValues:{b:NumberIntVal(5)}}}                     |                       |
      | tuple([string, bool, object({ a = string, b = optional(number, 5) })]) | Tuple([String, Bool, ObjectWithOptionalAttrs({a=String,b=Number},["b"])]) | nil                       | {"2": {Type:ObjectWithOptionalAttrs({a=String,b=Number},["b"]), DefaultValues:{b:NumberIntVal(5)}}}                 |                       |
      | object({ list = optional(list(object({ required = string, optional = optional(string) })), [])}) | ObjectWithOptionalAttrs({list=List(ObjectWithOptionalAttrs({required=String,optional=String},["optional"]))},["list"]) | {list: ListValEmpty(Object({required=String, optional=String}))} | nil                   |                       |
      | object({ list = optional(list(object({ required = string, optional = optional(string, "optional") })), [{ required = "required" }])}) | ObjectWithOptionalAttrs({list=List(ObjectWithOptionalAttrs({r=String,o=String},["o"]))},["list"]) | {list: ListVal([{r:StringVal("required"),o:NullVal(String)}])} | {list:{Type:List(ObjectWithOptionalAttrs({r=String,o=String},["o"])), Children:{"":{Type:ObjectWithOptionalAttrs({r=String,o=String},["o"]),DefaultValues:{o:StringVal("optional")}}}}} |      |
      | object({ a = optional(string, "hello"), b = optional(number, true) }) | ObjectWithOptionalAttrs({a=String, b=Number}, ["a","b"])      | {a: StringVal("hello")}     | nil                                                                                                                  | This default value is not compatible with the attribute's type constraint: number required, but have bool. |
      | object({name=string,meta=optional(string, "hello", "world")}) | nil                                                          | nil                         | nil                                                                                                                  | Optional attribute modifier expects at most two arguments: the attribute type, and a default value. |
      | map(object({ops=optional(list(string),[]),type=optional(string,"ABC"),type=optional(number)})) | Map(ObjectWithOptionalAttrs({ops=List(String),type=String},["ops","type"])) | nil | {"":{Type:ObjectWithOptionalAttrs({ops=List(String),type=String},["ops","type"]),DefaultValues:{ops:ListValEmpty(String),type:StringVal("ABC")}}} | Object constructor map keys must be unique. |

    # Notes on cty types:
    # - Bool, Number, String are cty.Bool, cty.Number, cty.String.
    # - DynamicPseudoType is cty.DynamicPseudoType.
    # - List(T), Map(T), Set(T) are cty.List(cty.T), etc.
    # - Object({name=T}) is cty.Object({"name": cty.T}).
    # - EmptyObject is cty.EmptyObject.
    # - Tuple([T1, T2]) is cty.Tuple([cty.T1, cty.T2]).
    # - EmptyTuple is cty.EmptyTuple.
    # - ObjectWithOptionalAttrs({name=T}, ["opt_attr_name"])
    # Notes on Defaults object:
    # - Type is the cty.Type of the Defaults.
    # - DefaultValues is a map[string]cty.Value.
    # - Children is a map[string]*Defaults. Simplified for readability in examples.
    # - 'nil' for type/map means the Defaults object itself is nil or the map is empty/nil.
