# Covers tests in ./ops_test.go
# Specifically, TestApplyPath and TestIndex

Feature: HCL cty.Value Operations (Path Application and Indexing)
  This feature tests operations on cty.Value objects, specifically applying
  a cty.Path to a value and indexing into collection values. It verifies
  correct value retrieval, error reporting for invalid operations, and
  preservation of cty marks.

  Scenario Outline: Applying cty.Path to a cty.Value
    Given a starting cty.Value <start_value_cty>
    And a cty.Path <path_cty>
    When `ApplyPath` is called with the start value and path
    Then the resulting cty.Value should be <expected_value_cty>
    And if an error is expected, the error summary and detail should be "<expected_error_message>"
    And if no error is expected, no diagnostics should be reported

    Examples:
      | start_value_cty                                  | path_cty                                 | expected_value_cty             | expected_error_message                                                                                                                               |
      | StringVal("hello")                               | (nil path)                               | StringVal("hello")             |                                                                                                                                                      |
      | StringVal("hello")                               | Path().Index(StringVal("boop"))          | NilVal                         | Invalid index: This value does not have any indices.                                                                                                 |
      | ListVal([StringVal("hello")])                    | Path().Index(NumberIntVal(0))            | StringVal("hello")             |                                                                                                                                                      |
      | ListVal([StringVal("hello")]).Mark("x")          | Path().Index(NumberIntVal(0))            | StringVal("hello").Mark("x")   |                                                                                                                                                      |
      | TupleVal([StringVal("hello")])                   | Path().Index(NumberIntVal(0))            | StringVal("hello")             |                                                                                                                                                      |
      | MapVal({a:StringVal("foo").Mark("x")}).Mark("x") | GetAttrPath("a")                         | StringVal("foo").Mark("x")     |                                                                                                                                                      |
      | ListValEmpty(String)                             | Path().Index(NumberIntVal(0))            | NilVal                         | Invalid index: The given key does not identify an element in this collection value: the collection has no elements.                                  |
      | ListVal([StringVal("hello")])                    | Path().Index(NumberIntVal(1))            | NilVal                         | Invalid index: The given key does not identify an element in this collection value: the given index is greater than or equal to the length of the collection. |
      | ListVal([StringVal("hello")]).Mark("boop")       | Path().Index(NumberIntVal(1))            | NilVal                         | Invalid index: The given key does not identify an element in this collection value.                                                                      |
      | ListVal([StringVal("hello")])                    | Path().Index(NumberIntVal(-1))           | NilVal                         | Invalid index: The given key does not identify an element in this collection value: a negative number is not a valid index for a sequence.                 |
      | ListVal([StringVal("hello")])                    | Path().Index(NumberFloatVal(0.5))        | NilVal                         | Invalid index: The given key does not identify an element in this collection value: indexing a sequence requires a whole number, but the given index has a fractional part. |
      | ListVal([StringVal("hello")])                    | Path().Index(NumberIntVal(0)).GetAttr("foo") | NilVal                       | Unsupported attribute: Can't access attributes on a primitive-typed value (string).                                                                    |
      | ListVal([EmptyObjectVal])                        | Path().Index(NumberIntVal(0)).GetAttr("foo") | NilVal                       | Unsupported attribute: This object does not have an attribute named "foo".                                                                             |
      | ListVal([EmptyObjectVal])                        | Path().GetAttr("foo")                    | NilVal                         | Unsupported attribute: Can't access attributes on a list of objects. Did you mean to access an attribute for a specific element of the list, or across all elements of the list? |
      | NullVal(List(String))                            | Path().Index(NumberIntVal(0))            | NilVal                         | Attempt to index null value: This value is null, so it does not have any indices.                                                                    |
      | NullVal(EmptyObject)                             | Path().GetAttr("foo")                    | NilVal                         | Attempt to get attribute from null value: This value is null, so it does not have any attributes.                                                    |
      | DynamicVal.Mark("marked")                        | GetAttrPath("foo")                       | DynamicVal.Mark("marked")      |                                                                                                                                                      |
      | ObjectVal({foo:"marked_val"}).Mark("marked")     | GetAttrPath("foo")                       | StringVal("marked_val").Mark("marked") |                                                                                                                                                      |
      | UnknownVal(Object({foo:Dyn})).Mark("marked")     | GetAttrPath("foo")                       | DynamicVal.Mark("marked")      |                                                                                                                                                      |
      | ListVal(["marked_val"]).Mark("marked")           | Path().Index(NumberIntVal(0))            | StringVal("marked_val").Mark("marked") |                                                                                                                                                      |
      | UnknownVal(List(String)).Mark("marked")          | Path().Index(NumberIntVal(0))            | UnknownVal(String).Mark("marked") |                                                                                                                                                      |
      | ListVal(["marked_val"]).Mark("marked")           | Path().Index(UnknownVal(Number))         | UnknownVal(String).Mark("marked")|                                                                                                                                                      |


  Scenario Outline: Indexing into a cty.Value collection
    Given a collection cty.Value <collection_cty>
    And a key cty.Value <key_cty>
    When `Index` is called with the collection and key
    Then the resulting cty.Value should be <expected_value_cty>
    And if an error is expected, the error summary should be "<expected_error_summary>"
    And if no error is expected, no diagnostics should be reported

    Examples:
      | collection_cty                             | key_cty                          | expected_value_cty        | expected_error_summary |
      | ListVal([StringVal("a")])                  | NumberIntVal(0).Mark("marked")   | StringVal("a").Mark("marked") |                        |
      | ListVal([StringVal("a")])                  | NumberIntVal(1).Mark("marked")   | DynamicVal                | "Invalid index"        |
      | ListVal([StringVal("a")])                  | NullVal(Number).Mark("marked")   | DynamicVal                | "Invalid index"        |
      | ListVal([StringVal("a")])                  | DynamicVal                       | DynamicVal                |                        |
      | ListVal([StringVal("a")])                  | StringVal("foo").Mark("marked")  | DynamicVal                | "Invalid index"        |
      | MapVal({foo: StringVal("a")})              | StringVal("foo").Mark("marked")  | StringVal("a").Mark("marked") |                        |
      | MapVal({foo: StringVal("a")})              | StringVal("bar").Mark("mark")    | DynamicVal                | "Invalid index"        |
      | ObjectVal({foo: StringVal("a")})           | StringVal("foo").Mark("marked")  | StringVal("a")            |                        | # Marks not maintained for object key access via Index
      | ObjectVal({foo: StringVal("a")})           | ListVal([NullVal(S)]).Mark("marked")| DynamicVal              | "Invalid index"        |
      | ObjectVal({foo: StringVal("a")})           | NumberIntVal(0).Mark("marked")   | DynamicVal                | "Invalid index"        |
      | UnknownVal(Object({foo: String}))          | StringVal("foo")                 | UnknownVal(String)        |                        |
      | UnknownVal(Object({foo: String}))          | NumberIntVal(0)                  | DynamicVal                | "Invalid index"        |

    # Notes on cty types and values:
    # - StringVal, NumberIntVal, ListVal, TupleVal, MapVal, ObjectVal, NullVal, UnknownVal, DynamicVal are cty constructors.
    # - S = cty.String, Dyn = cty.DynamicPseudoType.
    # - Path() refers to an empty cty.Path. GetAttrPath("name") creates a path for attribute access.
    # - .Mark("mark_name") is a cty mark.
    # - NilVal means cty.NilVal.
    # - For ApplyPath, expected_error_message is "Summary: Detail". For Index, it's just the Summary.
