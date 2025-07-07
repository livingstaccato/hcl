# Covers function typeexpr.TypeString in ./ext/typeexpr/public.go
# Based on test cases in ./ext/typeexpr/type_string_test.go (TestTypeString)

Feature: HCL Type to String Conversion (typeexpr.TypeString)
  This feature tests the `typeexpr.TypeString` function, which converts a `cty.Type`
  into its HCL native syntax string representation. This is useful for displaying
  type information to users familiar with HCL type expressions.

  Scenario Outline: Converting various cty.Type instances to HCL type strings
    Given a cty.Type represented as <cty_type_representation>
    When `typeexpr.TypeString` is called with this cty.Type
    Then the resulting string should be "<expected_hcl_string>"

    Examples:
      | cty_type_representation         | expected_hcl_string             |
      | `cty.DynamicPseudoType`         | `any`                           |
      | `cty.String`                    | `string`                        |
      | `cty.Number`                    | `number`                        |
      | `cty.Bool`                      | `bool`                          |
      | `cty.List(cty.Number)`          | `list(number)`                  |
      | `cty.Set(cty.Bool)`             | `set(bool)`                     |
      | `cty.Map(cty.String)`           | `map(string)`                   |
      | `cty.EmptyObject`               | `object({})`                    |
      | `cty.Object({"foo": cty.Bool})` | `object({foo=bool})`            |
      | `cty.Object({"foo": cty.Bool, "bar": cty.String})` | `object({bar=string,foo=bool})` | # Attributes sorted: bar, foo
      | `cty.EmptyTuple`                | `tuple([])`                     |
      | `cty.Tuple([cty.Bool])`         | `tuple([bool])`                 |
      | `cty.Tuple([cty.Bool, cty.String])` | `tuple([bool,string])`        |
      | `cty.List(cty.DynamicPseudoType)` | `list(any)`                     |
      | `cty.Tuple([cty.DynamicPseudoType])`| `tuple([any])`                  |
      | `cty.Object({"foo": cty.DynamicPseudoType})` | `object({foo=any})`           |
      | `cty.Object({"foo bar baz": cty.String})`    | `object({"foo bar baz"=string})`| # Non-identifier attribute name quoted

  Scenario: TypeString panics with CapsuleType (Conceptual)
    Given a cty.CapsuleType "myCapsule"
    When `typeexpr.TypeString` is called with "myCapsule"
    Then the operation should panic with message "TypeString does not support capsule types"
    # Note: This scenario is conceptual as setting up a cty.CapsuleType for this test is non-trivial
    # and not explicitly done in type_string_test.go. The Go function doc states this behavior.

    # Notes for table values:
    # - `cty_type_representation`: A string describing how the cty.Type is constructed in Go.
    #   E.g., `cty.List(cty.Number)` or `cty.Object({"name": cty.String})`.
    # - `<expected_hcl_string>`: The exact string expected from TypeString.
