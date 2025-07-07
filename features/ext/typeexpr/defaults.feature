# Covers ./ext/typeexpr/defaults.go (Defaults struct and Apply method)
# Based on test cases in ./ext/typeexpr/defaults_test.go (TestDefaults_Apply)

Feature: Applying Defaults to cty.Value using Type Expression Defaults
  This feature tests the `Defaults.Apply` method, which populates missing or null
  optional attributes within a `cty.Value` based on a predefined `Defaults` structure.
  This includes handling of nested objects, collections, unknown values, and cty value refinements.

  Background:
    Given `SimpleObject` is a cty.Type `object({a=string, b=optional(bool)})`
    And `NestedObject` is a cty.Type `object({c=optional(SimpleObject), d=number})`

  Scenario Outline: Applying defaults to cty.Values
    Given a `typeexpr.Defaults` object "D" configured with:
      Type: <DefaultsType_cty>
      DefaultValues: <DefaultValues_map>
      ChildrenDefaults: <ChildrenDefaults_map>
    And an input cty.Value <InputValue_cty>
    When `D.Apply(InputValue_cty)` is called
    Then the resulting cty.Value should be <ExpectedOutput_cty>

    Examples:
      # Basic cases
      | DefaultsType_cty        | DefaultValues_map | ChildrenDefaults_map | InputValue_cty                                  | ExpectedOutput_cty                              |
      | `Map(String)`           | {}                | {}                   | `MapVal({"a":"foo", "b":"bar"})`                  | `MapVal({"a":"foo", "b":"bar"})`                  | # No defaults defined
      | `SimpleObject`          | `{"b": True}`     | {}                   | `MapVal({"a":"foo"})`                             | `MapVal({"a":"foo", "b":"true"})`                 | # Simple default applied
      | `SimpleObject`          | `{"b": True}`     | {}                   | `UnknownVal(Map(String))`                       | `UnknownVal(Map(String))`                       | # Unknown input, no defaults applied to unknown itself
      | `SimpleObject`          | `{"b": True}`     | {}                   | `MapVal({"a":"foo", "b":"false"})`                | `MapVal({"a":"foo", "b":"false"})`                | # Default not overriding existing value
      | `SimpleObject`          | `{"b": True}`     | {}                   | `MapVal({"a":"foo", "b":NullVal(String)})`        | `MapVal({"a":"foo", "b":"true"})`                 | # Default overrides explicit null
      # Nested and Collections
      | `NestedObject`          | {}                | `{"c": {Type:SimpleObject, DV:{"b":False}}}` | `ObjVal({c:ObjVal({a:"foo"}), d:Num(5)})`       | `ObjVal({c:ObjVal({a:"foo",b:False}), d:Num(5)})` | # Nested default
      | `Map(SimpleObject)`     | {}                | `{"": {Type:SimpleObject, DV:{"b":True}}}`  | `MapVal({f:ObjV({a:"foo"}), b:ObjV({a:"bar"})})` | `MapVal({f:ObjV({a:"foo",b:True}), b:ObjV({a:"bar",b:True})})` | # Map of objects
      | `List(SimpleObject)`    | {}                | `{"": {Type:SimpleObject, DV:{"b":True}}}`  | `TupleVal([ObjV({a:"foo"}), ObjV({a:"bar"})])`   | `TupleVal([ObjV({a:"foo",b:True}), ObjV({a:"bar",b:True})])` | # List of objects (input as tuple)
      | `Tuple([SO,NO])`        | {}                | `{"0":{T:SO,DV:{b:F}}, "1":{T:NO,DV:{c:ObjV({a:"def",b:T})}}}` | `TupleVal([ObjV({a:"f"}),ObjV({d:5})])` | `TupleVal([ObjV({a:"f",b:F}),ObjV({c:ObjV({a:"def",b:T}),d:5})])` | # Tuple with distinct child defaults
      # Nulls and Unknowns with Defaults
      | `OWOA({req:S,opt:S},["opt"])` | `{"opt":"optional_val"}` | {}                   | `NullVal(Object({req:S,opt:S}))`                 | `NullVal(Object({req:S,opt:S}))`                 | # Null object input, defaults not applied to it
      | `OWOA({r:S,oObj:OWOA({nr:S,no:S},["no"])},["oObj"])` | `{"oObj":ObjV({nr:"req",no:Null(S)})}` | `{"oObj":{T:OWOA({nr:S,no:S},["no"]),DV:{"no":"opt"}}}` | `ObjV({r:"req",oObj:Null(Obj({nr:S,no:S}))})` | `ObjV({r:"req",oObj:ObjV({nr:"req",no:"opt"})})` | # Null nested object, defaults applied within
      | `OWOA({r:S,oObj:OWOA({nr:S,no:S},["no"])},["oObj"])` | `{"oObj":ObjV({nr:"req",no:Null(S)})}` | `{"oObj":{T:OWOA({nr:S,no:S},["no"]),DV:{"no":"opt"}}}` | `ObjV({r:"req"})` (oObj missing)                  | `ObjV({r:"req",oObj:ObjV({nr:"req",no:"opt"})})` | # Missing nested object, defaults applied
      # Nullability Refinement
      | `OWOA({foo:S},["foo"])`  | `{"foo":"bar_default"}` | {}                   | `ObjVal({"foo":UnknownVal(String)})`              | `ObjVal({"foo":UnknownVal(String).RefineNotNull()})` | # Optional with non-null default + unknown input
      | `OWOA({foo:S},["foo"])`  | `{"foo":NullVal(String)}`| {}                   | `ObjVal({"foo":UnknownVal(String)})`              | `ObjVal({"foo":UnknownVal(String)})`                | # Optional with null default + unknown input
      | `OWOA({foo:S},["foo"])`  | {}                      | {}                   | `ObjVal({"foo":UnknownVal(String)})`              | `ObjVal({"foo":UnknownVal(String)})`                | # Optional with no default + unknown input
      | `OWOA({foo:S},["foo"])`  | `{"foo":NullVal(String)}`| {}                   | `ObjVal({"foo":UnknownVal(String).RefineNotNull()})`| `ObjVal({"foo":UnknownVal(String).RefineNotNull()})`| # Optional with non-null unknown input
      | `OWOA({foo:S},["foo"])`  | `{"foo":"bar_default"}` | {}                   | `ObjVal({"foo":DynamicVal})`                      | `ObjVal({"foo":DynamicVal})`                        | # Optional with dynamic input, no refinement

    # Notes for table values:
    # - Type shorthands: `Map(String)`, `SimpleObject` (SO), `NestedObject` (NO), `OWOA(attrs,opts)` (ObjectWithOptionalAttrs), `S` (String), `Num` (Number), `F` (False), `T` (True).
    # - Value shorthands: `MapVal({...})`, `ObjVal({...})`, `TupleVal([...])`, `UnknownVal(Type)`, `NullVal(Type)`, `Num(5)`, `Str("text")`.
    # - `DV` in ChildrenDefaults means `DefaultValues`. `T` means `Type`.
    # - `ObjV` is shorthand for `cty.ObjectVal`.
    # - `(nil or empty)` means the map is nil or empty.
    # - `.RefineNotNull()` indicates a cty value refinement.
