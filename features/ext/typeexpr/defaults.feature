# Covers tests in ./ext/typeexpr/defaults_test.go
# Specifically, TestDefaults_Apply

Feature: Applying Defaults to cty.Value based on Defaults Object
  This feature tests the `Apply` method of the `Defaults` object, which is used
  to populate missing or null optional attributes in a cty.Value with their
  predefined default values. This includes handling of nested objects,
  collections (maps, lists, sets, tuples), unknown values, and value refinements.

  Background:
    Given a `Defaults` object defining a cty.Type, optional DefaultValues, and optional child Defaults.
    And an input `cty.Value`.

  Scenario Outline: Applying defaults to various cty.Value structures
    Given a Defaults object with type <defaults_type_cty>
    And DefaultValues <default_values_map>
    And Children <children_map>
    And an input cty.Value <input_value_cty>
    When the Defaults object's `Apply` method is called with the input value
    Then the resulting cty.Value should be <expected_value_cty>

    Examples:
      # Basic cases
      | defaults_type_cty                                  | default_values_map | children_map | input_value_cty                                 | expected_value_cty                              |
      | Map(String)                                        | (none)             | (none)       | MapVal({"a":"foo", "b":"bar"})                  | MapVal({"a":"foo", "b":"bar"})                  | # No defaults
      | ObjectWithOptionalAttrs({a=String,b=Bool},["b"])    | {b: True}          | (none)       | MapVal({"a":"foo"})                             | MapVal({"a":"foo", "b":"true"})                 | # Simple default applied
      | ObjectWithOptionalAttrs({a=String,b=Bool},["b"])    | {b: True}          | (none)       | UnknownVal(Map(String))                         | UnknownVal(Map(String))                         | # Unknown input value
      | ObjectWithOptionalAttrs({a=String,b=Bool},["b"])    | {b: True}          | (none)       | MapVal({"a":"foo", "b":"false"})                | MapVal({"a":"foo", "b":"false"})                | # Default not overriding specified value
      | ObjectWithOptionalAttrs({a=String,b=Bool},["b"])    | {b: True}          | (none)       | MapVal({"a":"foo", "b":NullVal(String)})        | MapVal({"a":"foo", "b":"true"})                 | # Default overrides explicit null
      # Nested objects
      | ObjectWithOptionalAttrs({c=SO,d=Number},["c"])      | (none)             | {c: {Type:SO, DefaultValues:{b:False}}} | ObjectVal({c:ObjectVal({a:"foo"}), d:NumberIntVal(5)}) | ObjectVal({c:ObjectVal({a:"foo",b:False}), d:NumberIntVal(5)}) | # Nested default
      # Collections of objects
      | Map(SO)                                            | (none)             | {"": {Type:SO, DefaultValues:{b:True}}} | MapVal({f:Obj({a:"foo"}),b:Obj({a:"bar"})}) | MapVal({f:Obj({a:"foo",b:True}),b:Obj({a:"bar",b:True})}) | # Map of objects
      | Map(SO)                                            | (none)             | {"": {Type:SO, DefaultValues:{b:True}}} | ObjectVal({f:Obj({a:"foo"}),b:Obj({a:"bar"})}) | ObjectVal({f:Obj({a:"foo",b:True}),b:Obj({a:"bar",b:True})}) | # Map of objects (input as object)
      | List(SO)                                           | (none)             | {"": {Type:SO, DefaultValues:{b:True}}} | TupleVal([Obj({a:"foo"}),Obj({a:"bar"})]) | TupleVal([Obj({a:"foo",b:True}),Obj({a:"bar",b:True})]) | # List of objects (input as tuple)
      # Tuples with different element defaults
      | Tuple([SO, NO])                                    | (none)             | {0:{Type:SO,DefaultValues:{b:False}}, 1:{Type:NO,DefaultValues:{c:Obj({a:"default",b:True})}}} | TupleVal([Obj({a:"foo"}),Obj({d:5})]) | TupleVal([Obj({a:"foo",b:False}),Obj({c:Obj({a:"default",b:True}),d:5})]) |
      # Deeply nested defaults & default-within-default
      | Set(NO)                                            | (none)             | {"":{Type:NO, Children:{c:{Type:SO,DefaultValues:{b:True}}}}} | TupleVal([Obj({c:Obj({a:"foo"}),d:5}),Obj({d:7})]) | TupleVal([Obj({c:Obj({a:"foo",b:True}),d:5}),Obj({d:7})]) | # Set of nested, no default sub-object
      | Set(NO)                                            | (none)             | {"":{Type:NO, DefaultValues:{c:EmptyObjectVal}, Children:{c:{Type:SO,DefaultValues:{b:True}}}}} | TupleVal([Obj({c:Obj({a:"foo"}),d:5}),Obj({d:7})]) | TupleVal([Obj({c:Obj({a:"foo",b:True}),d:5}),Obj({c:Obj({b:True}),d:7})]) | # Set of nested, empty default sub-object
      | Set(NO)                                            | (none)             | {"":{Type:NO, DefaultValues:{c:Obj({a:"fallback",b:False})}, Children:{c:{Type:SO,DefaultValues:{b:True}}}}} | TupleVal([Obj({c:Obj({a:"foo"}),d:5}),Obj({d:7})]) | TupleVal([Obj({c:Obj({a:"foo",b:True}),d:5}),Obj({c:Obj({a:"fallback",b:False}),d:7})]) | # Set of nested, overriding default sub-object
      | Set(NO)                                            | (none)             | {"":{Type:NO, DefaultValues:{c:Obj({a:"fallback",b:NullVal(Bool)})}, Children:{c:{Type:SO,DefaultValues:{b:True}}}}} | TupleVal([Obj({c:Obj({a:"foo"}),d:5}),Obj({d:7})]) | TupleVal([Obj({c:Obj({a:"foo",b:True}),d:5}),Obj({c:Obj({a:"fallback",b:True}),d:7})]) | # Set of nested, nulls in default sub-object overridden
      # Null objects and defaults
      | OWOA({req=S,opt=S},["opt"])                         | {opt:"optional"}   | (none)       | NullVal(Object({req:S,opt:S}))                  | NullVal(Object({req:S,opt:S}))                  | # Null object doesn't get defaults
      | OWOA({req=S,optObj=OWOA({nReq=S,nOpt=S},["nOpt"])},["optObj"]) | {optObj:Obj({nReq:"req",nOpt:NullVal(S)})} | {optObj:{Type:OWOA({nReq=S,nOpt=S},["nOpt"]),DefaultValues:{nOpt:"opt"}}} | Obj({req:"req",optObj:NullVal(ObjType)}) | Obj({req:"req",optObj:Obj({nReq:"req",nOpt:"opt"})}) | # Unset default (null) still applied
      | OWOA({req=S,optObj=OWOA({nReq=S,nOpt=S},["nOpt"])},["optObj"]) | {optObj:Obj({nReq:"req",nOpt:NullVal(S)})} | {optObj:{Type:OWOA({nReq=S,nOpt=S},["nOpt"]),DefaultValues:{nOpt:"opt"}}} | Obj({req:"req"})                               | Obj({req:"req",optObj:Obj({nReq:"req",nOpt:"opt"})}) | # Unset default (missing) still applied
      # All children optional with defaults
      | OWOA({sets=OWOA({s1=S,s2=N},["s1","s2"])},["sets"]) | {sets:EmptyObjVal} | {sets:{Type:OWOA({s1=S,s2=N},["s1","s2"]),DefaultValues:{s1:"",s2:0}}} | EmptyObjVal | Obj({sets:Obj({s1:"",s2:0})}) | # All children and nested optional with defaults
      | OWOA({sets=OWOA({s1=S,s2=N},["s1","s2"])},["sets"]) | (none)             | {sets:{Type:OWOA({s1=S,s2=N},["s1","s2"]),DefaultValues:{s1:"",s2:0}}} | EmptyObjVal | EmptyObjVal                   | # Nested optional, but direct child has no default
      # Tuples and Lists with Dynamic Types
      | List(OWOA({name=S,taints=List(Map(Dyn))},["name","taints"])) | (none) | {"":{Type:OWOA({name=S,taints=List(Map(Dyn))},["name","taints"]),DefaultValues:{name:"default",taints:ListValEmpty(Map(Dyn))}}} | TupleVal([Obj({name:"np-32"}),Obj({name:"ne-32",taints:ListVal([MapVal({k:"etsy",v:"envoy"})])})]) | TupleVal([Obj({name:"np-32",taints:ListValEmpty(Map(Dyn))}),Obj({name:"ne-32",taints:ListVal([MapVal({k:"etsy",v:"envoy"})])})]) |
      | List(OWOA({name=S,taints=List(Map(Dyn))},["name","taints"])) | (none) | {"":{Type:OWOA({name=S,taints=List(Map(Dyn))},["name","taints"]),DefaultValues:{name:"default",taints:ListValEmpty(Map(Dyn))}}} | ListVal([Obj({name:"np-32",taints:NullVal(List(Map(S)))}),Obj({name:"ne-32",taints:ListVal([MapVal({k:"etsy",v:"envoy"})])})]) | ListVal([Obj({name:"np-32",taints:ListValEmpty(Map(S))}),Obj({name:"ne-32",taints:ListVal([MapVal({k:"etsy",v:"envoy"})])})]) |
      # Type mismatch handling
      | Map(OWOA({desc=S,rules=Map(OWOA({d=S,dp=List(S),da=List(S),ta=S,tp=S},["da"]))},["desc"])) | (none) | {"":{Type:OWOA_Outer,DefaultValues:{desc:"unknown"},Children:{rules:{Type:Map(OWOA_Inner),Children:{"":{Type:OWOA_Inner,DefaultValues:{da:ListValEmpty(S)}}}}}}} | MapVal({mysql:Obj({rules:Obj({d:"Pf",dp:["3306"],da:["1.1"],ta:"1.1",tp:"3306"})})}) | MapVal({mysql:Obj({desc:"unknown",rules:Obj({d:"Pf",dp:["3306"],da:["1.1"],ta:"1.1",tp:"3306"})})}) |
      # Nullability and Refinements
      | OWOA({foo=S},["foo"])                               | {foo:"bar"}        | (none)       | Obj({foo:UnknownVal(S)})                        | Obj({foo:UnknownVal(S).RefineNotNull()})        | # Optional with non-null default is not nullable
      | OWOA({foo=S},["foo"])                               | {foo:NullVal(S)}   | (none)       | Obj({foo:UnknownVal(S)})                        | Obj({foo:UnknownVal(S)})                        | # Optional with null default can be null
      | OWOA({foo=S},["foo"])                               | (none)             | (none)       | Obj({foo:UnknownVal(S)})                        | Obj({foo:UnknownVal(S)})                        | # Optional with no default can be null
      | OWOA({foo=S},["foo"])                               | {foo:NullVal(S)}   | (none)       | Obj({foo:UnknownVal(S).RefineNotNull()})        | Obj({foo:UnknownVal(S).RefineNotNull()})        | # Optional with non-null unknown input
      | OWOA({foo=S},["foo"])                               | {foo:"bar"}        | (none)       | Obj({foo:DynamicVal})                           | Obj({foo:DynamicVal})                           | # Optional with dynamic input

    # Type shorthands used in examples:
    # SO = ObjectWithOptionalAttrs({a=String,b=Bool},["b"])
    # NO = ObjectWithOptionalAttrs({c=SO,d=Number},["c"])
    # OWOA(attrs, opts) = ObjectWithOptionalAttrs(attrs, opts)
    # S = String, N = Number, B = Bool, Dyn = DynamicPseudoType
    # ObjType = Object({nested_required=S, nested_optional=S})
    # OWOA_Outer = OWOA({desc=S,rules=Map(OWOA_Inner)},["desc"])
    # OWOA_Inner = OWOA({d=S,dp=List(S),da=List(S),ta=S,tp=S},["da"])
    # MapVal, ObjectVal, TupleVal, ListVal, UnknownVal, NullVal, EmptyObjectVal are cty value constructors.
    # (none) for maps means nil or empty map.
    # RefineNotNull() is a cty refinement.
