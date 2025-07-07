# Covers functions in ./ext/typeexpr/public.go (Type, TypeConstraint, TypeConstraintWithDefaults)
# and the internal getType logic in ./ext/typeexpr/get_type.go
# Based on test cases in ./ext/typeexpr/get_type_test.go

Feature: HCL Type Expression Parsing and Default Value Extraction
  This feature tests the parsing of HCL type expressions (like `string`, `list(number)`, `object({name=string})`)
  into `cty.Type` values, including handling of the `any` keyword, type constructors,
  the `optional` modifier for object attributes, and extraction of default values
  when parsing type constraints. It covers both native HCL syntax and JSON representation.

  Scenario Outline: Parsing HCL type expressions (Native Syntax)
    Given the HCL type expression source: "<source>"
    And the 'is_constraint' flag is <is_constraint>
    When the expression is parsed to get a cty.Type (using `typeexpr.Type` or `typeexpr.TypeConstraint`)
    Then the resulting cty.Type should be <expected_type_cty_string>
    And if an error is expected, its detail message should be "<expected_error_detail>"
    And if no error is expected, no error diagnostics should be reported

    Examples:
      # Keywords
      | source   | is_constraint | expected_type_cty_string | expected_error_detail                                                                          |
      | `bool`   | false         | `cty.Bool`               |                                                                                                |
      | `number` | false         | `cty.Number`             |                                                                                                |
      | `string` | false         | `cty.String`             |                                                                                                |
      | `any`    | false         | `cty.DynamicPseudoType`  | The keyword "any" cannot be used in this type specification: an exact type is required.        |
      | `any`    | true          | `cty.DynamicPseudoType`  |                                                                                                |
      # Keyword constructors (invalid uses - missing args)
      | `list`   | false         | `cty.DynamicPseudoType`  | The list type constructor requires one argument specifying the element type.                 |
      | `map`    | false         | `cty.DynamicPseudoType`  | The map type constructor requires one argument specifying the element type.                  |
      | `object` | false         | `cty.DynamicPseudoType`  | The object type constructor requires one argument specifying the attribute types and values as a map. |
      | `tuple`  | false         | `cty.DynamicPseudoType`  | The tuple type constructor requires one argument specifying the element types as a list.       |
      # Primitive type keywords with unexpected arguments
      | `bool()`   | false         | `cty.DynamicPseudoType`  | Primitive type keyword "bool" does not expect arguments.                                     |
      | `any()`    | true          | `cty.DynamicPseudoType`  | Type constraint keyword "any" does not expect arguments.                                     |
      # Valid constructors
      | `list(string)`           | false         | `cty.List(cty.String)` |                                                                                                |
      | `set(string)`            | false         | `cty.Set(cty.String)`  |                                                                                                |
      | `map(string)`            | false         | `cty.Map(cty.String)`  |                                                                                                |
      | `object({})`             | false         | `cty.EmptyObject`      |                                                                                                |
      | `object({name=string})`  | false         | `cty.Object({"name": cty.String})` |                                                                                       |
      | `tuple([])`              | false         | `cty.EmptyTuple`       |                                                                                                |
      | `tuple([string, bool])`  | false         | `cty.Tuple([cty.String, cty.Bool])` |                                                                                      |
      # Constructor argument count/type errors
      | `list()`                 | false         | `cty.DynamicPseudoType`  | The list type constructor requires one argument specifying the element type.                 |
      | `list(string, string)`   | false         | `cty.DynamicPseudoType`  | The list type constructor requires one argument specifying the element type.                 |
      | `object(string)`         | false         | `cty.DynamicPseudoType`  | Object type constructor requires a map whose keys are attribute names and whose values are the corresponding attribute types. |
      | `tuple(string)`          | false         | `cty.DynamicPseudoType`  | Tuple type constructor requires a list of element types.                                     |
      # Invalid keyword/constructor usage
      | `object({"name"=string})`| false         | `cty.EmptyObject`        | Object constructor map keys must be attribute names.                                           | # Parser recovers to EmptyObject
      | `object({name=nope})`    | false         | `cty.Object({"name": cty.DynamicPseudoType})` | The keyword "nope" is not a valid type specification.                                     |
      | `list("string")`         | false         | `cty.List(cty.DynamicPseudoType)` | A type specification is either a primitive type keyword (bool, number, string) or a complex type constructor call, like list(string). |
      # Nested constructors
      | `list(object({}))`       | false         | `cty.List(cty.EmptyObject)` |                                                                                                |
      # Optional modifier
      | `object({name=string,age=optional(number)})` | true  | `cty.ObjectWithOptionalAttrs({"name":cty.String, "age":cty.Number}, ["age"])` |                               |
      | `object({name=string,age=optional(number)})` | false | `cty.Object({"name":cty.String, "age":cty.Number})` | Optional attribute modifier is only for type constraints, not for exact types.             |
      | `optional(string)`       | false         | `cty.DynamicPseudoType`  | Keyword "optional" is valid only as a modifier for object type attributes.                 |

  Scenario Outline: Parsing HCL type expressions (JSON Syntax)
    Given a JSON HCL body string: "<source_json_body>" containing a type expression for attribute "expr"
    And the 'is_constraint' flag is <is_constraint>
    When the JSON body is parsed and the "expr" attribute's expression is processed to get a cty.Type (using `typeexpr.Type` or `typeexpr.TypeConstraint`)
    Then the resulting cty.Type should be <expected_type_cty_string>
    And if an error is expected, its detail message should be "<expected_error_detail>"
    And if no error is expected, no error diagnostics should be reported

    Examples:
      | source_json_body   | is_constraint | expected_type_cty_string | expected_error_detail                                                              |
      | `{"expr":"bool"}`    | false         | `cty.Bool`               |                                                                                    |
      | `{"expr":"list(bool)"}` | false         | `cty.List(cty.Bool)`   |                                                                                    |
      | `{"expr":"list"}`    | false         | `cty.DynamicPseudoType`  | The list type constructor requires one argument specifying the element type.     |

  Scenario Outline: Extracting Defaults from HCL type expressions with optional attributes
    Given the HCL type expression source: "<source>"
    When the expression is parsed using `typeexpr.TypeConstraintWithDefaults`
    Then the resulting cty.Type should be <expected_type_cty_string>
    And the resulting Defaults object should have DefaultValues <expected_default_values_map_repr>
    And the resulting Defaults object should have Children <expected_children_map_repr>
    And if an error is expected, its detail message should be "<expected_error_detail>"
    And if no error is expected, no error diagnostics should be reported

    Examples:
      | source                                                  | expected_type_cty_string                                     | expected_default_values_map_repr | expected_children_map_repr                                                                                                | expected_error_detail |
      | `bool`                                                  | `cty.Bool`                                                   | (nil or empty)                   | (nil or empty)                                                                                                            |                       |
      | `object({ a = string, b = optional(number, 5) })`       | `cty.ObjectWithOptionalAttrs({"a":cty.String, "b":cty.Number}, ["b"])` | `{"b": NumberIntVal(5)}`         | (nil or empty)                                                                                                            |                       |
      | `object({ a = optional(object({ b = optional(number, 5) }), {}) })` | `cty.ObjectWithOptionalAttrs({"a":OWOA({"b":Num},["b"])},["a"])` | `{"a": ObjectVal({"b":NullVal(Number)})}` | `{"a": {Type:OWOA({"b":Num},["b"]), DV:{"b":Num(5)}}}`                                                       |                       | # OWOA short for ObjectWithOptionalAttrs, DV for DefaultValues
      | `map(object({ a = string, b = optional(number, 5) }))`  | `cty.Map(OWOA({"a":Str,"b":Num},["b"]))`                      | (nil or empty)                   | `{"": {Type:OWOA({"a":Str,"b":Num},["b"]), DV:{"b":Num(5)}}}`                                                |                       |
      | `object({ a = optional(string, "hello"), b = optional(number, true) })` | `cty.ObjectWithOptionalAttrs({"a":cty.String, "b":cty.Number}, ["a","b"])` | `{"a": StringVal("hello")}`      | (nil or empty)                                                                                                            | This default value is not compatible with the attribute's type constraint: number required, but have bool. |
      | `object({name=string,meta=optional(string, "hello", "world")})` | `cty.Object({"name":cty.String, "meta":cty.String})`       | (nil or empty)                   | (nil or empty)                                                                                                            | Optional attribute modifier expects at most two arguments: the attribute type, and a default value. |

    # Notes for cty.Type and Defaults representation:
    # - `expected_type_cty_string`: A string representation of the expected cty.Type (e.g., `cty.String`, `cty.List(cty.Number)`).
    # - `expected_default_values_map_repr`: Simplified string representation of the map[string]cty.Value (e.g., `{"b": NumberIntVal(5)}`). (nil or empty) for no defaults.
    # - `expected_children_map_repr`: Simplified string representation of map[string]*Defaults. (nil or empty) for no children.
    #   Example: `{"a": {Type:ObjType, DV:{def_val}}}` where ObjType is the cty.Type of the child default and DV is its DefaultValues.
    #   `""` as a key in children_map_repr refers to defaults for elements of a collection type.
    #   `"2"` as a key refers to the defaults for the element at index 2 of a tuple type.
    # - Primitive types (Bool, Number, String), EmptyObject, EmptyTuple, DynamicPseudoType are direct cty types.
    # - OWOA is shorthand for cty.ObjectWithOptionalAttrs. Str for cty.String, Num for cty.Number.
    # - The public functions `Type`, `TypeConstraint`, `TypeConstraintWithDefaults` call the internal `getType` with different flags.
    #   This feature file tests the outcomes of these public functions by verifying the `cty.Type` and diagnostics.
    #   The `Defaults` object is specifically checked for `TypeConstraintWithDefaults`.
