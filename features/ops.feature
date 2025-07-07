# Covers functions hcl.Index, hcl.GetAttr, hcl.ApplyPath in ./ops.go
# Based on test cases in ./ops_test.go (TestApplyPath, TestIndex)

Feature: HCL Operations - Indexing, Attribute Access, and Path Application
  This feature tests HCL's core operations for accessing parts of cty.Values,
  specifically indexing into collections (`hcl.Index`), getting attributes from
  objects/maps (`hcl.GetAttr`), and applying a multi-step `cty.Path` (`hcl.ApplyPath`).
  It covers various value types, success cases, error conditions, and cty mark propagation.

  Scenario Outline: Indexing into a cty.Value collection using hcl.Index
    Given a collection cty.Value <collection_cty_repr>
    And a key cty.Value <key_cty_repr>
    And an optional source range for diagnostics
    When `hcl.Index(collection, key, range)` is called
    Then the resulting cty.Value should be <expected_value_repr>
    And if an error is expected, the first diagnostic summary should be "<expected_error_summary>"
    And if an error is expected, the first diagnostic detail should contain "<expected_error_detail_contains>"
    And if no error is expected, no diagnostics should be reported

    Examples:
      | collection_cty_repr             | key_cty_repr        | expected_value_repr        | expected_error_summary | expected_error_detail_contains |
      | `ListVal([Str("a")])`           | `Num(0)`            | `Str("a")`                 |                        |                                |
      | `ListVal([Str("a")])`           | `Num(0).Mark("m")`  | `Str("a").Mark("m")`       |                        |                                |
      | `ListVal([Str("a")])`           | `Num(1)`            | `DynamicVal`               | Invalid index          | greater than or equal to the length |
      | `ListValEmpty(Str)`             | `Num(0)`            | `DynamicVal`               | Invalid index          | collection has no elements     |
      | `ListVal([Str("a")])`           | `Num(-1)`           | `DynamicVal`               | Invalid index          | negative number is not a valid index |
      | `ListVal([Str("a")])`           | `Num(0.5)`          | `DynamicVal`               | Invalid index          | index has a fractional part    |
      | `ListVal([Str("a")])`           | `Str("foo")`        | `DynamicVal`               | Invalid index          | number required                |
      | `MapVal({foo:Str("a")})`        | `Str("foo")`        | `Str("a")`                 |                        |                                |
      | `MapVal({foo:Str("a")})`        | `Str("foo").Mark("m")`| `Str("a").Mark("m")`       |                        |                                |
      | `MapVal({foo:Str("a")})`        | `Str("bar")`        | `DynamicVal`               | Invalid index          | does not identify an element   |
      | `ObjectVal({foo:Str("a")})`     | `Str("foo")`        | `Str("a")`                 |                        |                                | # Object indexing uses GetAttr logic
      | `ObjectVal({foo:Str("a")})`     | `Str("foo").Mark("m")`| `Str("a")`                 |                        |                                | # Marks not kept for obj keys via Index
      | `ObjectVal({foo:Str("a")})`     | `Num(0)`            | `DynamicVal`               | Invalid index          | object only supports lookup by name |
      | `NullVal(List(Str))`            | `Num(0)`            | `DynamicVal`               | Attempt to index null  | value is null                  |
      | `ListVal([Str("a")])`           | `NullVal(Num)`      | `DynamicVal`               | Invalid index          | Can't use a null value         |
      | `ListVal([Str("a")])`           | `DynamicVal`        | `DynamicVal`               |                        |                                | # Dynamic key
      | `SetVal([Str("a")])`            | `Str("a")`          | `DynamicVal`               | Invalid index          | Elements of a set are identified |
      | `Str("primitive")`              | `Num(0)`            | `DynamicVal`               | Invalid index          | value does not have any indices|
      | `UnknownVal(Obj({f:Str}))`      | `Str("f")`          | `UnknownVal(String)`       |                        |                                |

  Scenario Outline: Getting an attribute from a cty.Value using hcl.GetAttr
    Given an object cty.Value <object_cty_repr>
    And an attribute name "<attr_name>"
    And an optional source range for diagnostics
    When `hcl.GetAttr(object, attr_name, range)` is called
    Then the resulting cty.Value should be <expected_value_repr>
    And if an error is expected, the first diagnostic summary should be "<expected_error_summary>"
    And if an error is expected, the first diagnostic detail should contain "<expected_error_detail_contains>"
    And if no error is expected, no diagnostics should be reported

    Examples:
      | object_cty_repr                 | attr_name | expected_value_repr     | expected_error_summary | expected_error_detail_contains |
      | `ObjVal({foo:Str("bar")})`      | "foo"     | `Str("bar")`            |                        |                                |
      | `ObjVal({f:Str("b")}).Mark("m")`| "f"       | `Str("b").Mark("m")`    |                        |                                |
      | `MapVal({foo:Str("bar")})`      | "foo"     | `Str("bar")`            |                        |                                |
      | `ObjVal({foo:Str("bar")})`      | "baz"     | `DynamicVal`            | Unsupported attribute  | does not have an attribute named "baz" |
      | `MapVal({foo:Str("bar")})`      | "baz"     | `DynamicVal`            | Missing map element    | does not have an element with key "baz" |
      | `NullVal(Obj({}))`              | "foo"     | `DynamicVal`            | Attempt to get attribute| value is null                  |
      | `Str("primitive")`              | "foo"     | `DynamicVal`            | Unsupported attribute  | Can't access attributes on a primitive |
      | `ListVal([ObjVal({a:T})])`      | "a"       | `DynamicVal`            | Unsupported attribute  | Can't access attributes on a list |
      | `SetVal([ObjVal({a:T})])`       | "a"       | `DynamicVal`            | Unsupported attribute  | Can't access attributes on a set   |
      | `DynamicVal`                    | "foo"     | `DynamicVal`            |                        |                                |
      | `UnknownVal(Obj({f:Str}))`      | "f"       | `UnknownVal(String)`    |                        |                                |

  Scenario Outline: Applying a cty.Path to a cty.Value using hcl.ApplyPath
    Given a starting cty.Value <start_value_repr>
    And a cty.Path constructed as: <path_description_list> # e.g., ["GetAttr(foo)", "Index(Num(0))"]
    And an optional source range for diagnostics
    When `hcl.ApplyPath(start_value, path, range)` is called
    Then the resulting cty.Value should be <expected_value_repr>
    And if an error is expected, the first diagnostic summary should be "<expected_error_summary>"
    And if an error is expected, the first diagnostic detail should contain "<expected_error_detail_contains>"
    And if no error is expected, no diagnostics should be reported

    Examples:
      | start_value_repr                        | path_description_list                     | expected_value_repr        | expected_error_summary | expected_error_detail_contains |
      | `Str("hello")`                          | `[]` (empty path)                         | `Str("hello")`             |                        |                                |
      | `ListVal([Str("hi")])`                  | `["Index(Num(0))"]`                       | `Str("hi")`                |                        |                                |
      | `ListVal([ObjVal({a:T})])`              | `["Index(Num(0))", "GetAttr(a)"]`         | `True`                     |                        |                                |
      | `ListVal([Str("hi")])`                  | `["Index(Num(0))", "GetAttr(foo)"]`         | `DynamicVal`               | Unsupported attribute  | Can't access attributes on a primitive |
      | `Str("no_indices")`                     | `["Index(Num(0))"]`                       | `DynamicVal`               | Invalid index          | value does not have any indices|
      | `ObjVal({a:Str("b")}).Mark("m")`        | `["GetAttr(a)"]`                          | `Str("b").Mark("m")`       |                        |                                |
      | `ListVal([Str("v")]).Mark("m")`         | `["Index(Num(0))"]`                       | `Str("v").Mark("m")`       |                        |                                |
      | `UnknownVal(List(Str)).Mark("m")`       | `["Index(Num(0))"]`                       | `UnknownVal(Str).Mark("m")`|                        |                                |
      | `ListVal([Str("v")]).Mark("m")`         | `["Index(UnknownVal(Num))"]`              | `UnknownVal(Str).Mark("m")`|                        |                                |


    # Notes for table values:
    # - cty value representations are simplified: Str("a"), Num(0), True, ListVal([...]), MapVal({...}), ObjVal({...}), NullVal(Type), UnknownVal(Type), DynamicVal.
    # - `.Mark("m")` indicates a cty mark.
    # - Path description list: each string describes a cty.PathStep, e.g., "GetAttr(name)" or "Index(KeyValue)".
    # - Error detail contains is a substring match for precision.
