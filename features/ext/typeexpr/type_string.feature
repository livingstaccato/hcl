# Covers tests in ./ext/typeexpr/type_string_test.go
# Specifically, TestTypeString

Feature: HCL Type to String Conversion
  This feature tests the `TypeString` function, which converts a `cty.Type`
  into its HCL type expression string representation.

  Scenario Outline: Converting cty.Type to HCL type string
    Given the cty.Type: <cty_type_representation>
    When `TypeString` is called with this type
    Then the resulting string should be "<expected_hcl_string>"

    Examples:
      | cty_type_representation         | expected_hcl_string        |
      | DynamicPseudoType               | any                        |
      | String                          | string                     |
      | Number                          | number                     |
      | Bool                            | bool                       |
      | List(Number)                    | list(number)               |
      | Set(Bool)                       | set(bool)                  |
      | Map(String)                     | map(string)                |
      | EmptyObject                     | object({})                 |
      | Object({"foo": Bool})           | object({foo=bool})         |
      | Object({"foo": Bool, "bar": String}) | object({bar=string,foo=bool}) | # Attributes are sorted
      | EmptyTuple                      | tuple([])                  |
      | Tuple([Bool])                   | tuple([bool])              |
      | Tuple([Bool, String])           | tuple([bool,string])       |
      | List(DynamicPseudoType)         | list(any)                  |
      | Tuple([DynamicPseudoType])      | tuple([any])               |
      | Object({"foo": DynamicPseudoType}) | object({foo=any})          |
      | Object({"foo bar baz": String}) | object({"foo bar baz"=string}) | # Non-identifier attribute names are quoted

    # Notes on cty_type_representation:
    # - Types like String, Number, Bool, DynamicPseudoType refer to their cty counterparts.
    # - List(T), Set(T), Map(T) construct cty collection types.
    # - Object({key: Type, ...}) constructs a cty object type.
    # - EmptyObject is cty.EmptyObject.
    # - Tuple([Type, ...]) constructs a cty tuple type.
    # - EmptyTuple is cty.EmptyTuple.
