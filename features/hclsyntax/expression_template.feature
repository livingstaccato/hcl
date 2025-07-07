# Covers tests in ./hclsyntax/expression_template_test.go
# Specifically, TestTemplateExprParseAndValue, TestTemplateExprGracefulValue,
# TestTemplateExprWrappedGracefulValue, and TestTemplateExprIsStringLiteral.

Feature: HCL Syntax - Template Expression Parsing and Evaluation
  This feature tests the parsing of HCL template expressions (both quoted strings
  and heredocs containing interpolations `${}` and control sequences `%{}`)
  and their evaluation to `cty.Value` objects. It covers literal text,
  interpolations, control structures (if/else, for), whitespace stripping (~),
  escape sequences, and handling of cty marks and unknown values.

  Scenario Outline: Parsing and evaluating HCL template expressions
    Given an HCL template input string: "<template_string>"
    And an evaluation context:
      | type      | details                                       |
      | variables | <variables_map_json>                          |
    When the template string is parsed using `ParseTemplate`
    And the parsed template expression is evaluated with the context
    Then the number of total diagnostics (parse + eval) should be <diagnostics_count>
    And the resulting cty.Value should be <expected_cty_value_string>

    Examples:
      # Basic literals and interpolations
      | template_string                | variables_map_json | diagnostics_count | expected_cty_value_string           |
      | `1`                            | {}                 | 0                 | StringVal("1")                      | # Number literal becomes string
      | `(1)`                          | {}                 | 0                 | StringVal("(1)")                    | # Parentheses are literal
      | `true`                         | {}                 | 0                 | StringVal("true")                   |
      | `\nhello world\n`              | {}                 | 0                 | StringVal("\\nhello world\\n")        |
      | `hello ${"world"}`             | {}                 | 0                 | StringVal("hello world")            |
      | `hello\\nworld`                | {}                 | 0                 | StringVal("hello\\\\nworld")        | # Backslash escapes not processed in bare template
      | `hello ${12.5}`                | {}                 | 0                 | StringVal("hello 12.5")             |
      | `silly ${"${"nesting"}"}`      | {}                 | 0                 | StringVal("silly nesting")          |
      | `hello $${escaped}`           | {}                 | 0                 | StringVal("hello ${escaped}")       | # Escaped interpolation
      | `hello %%{directive}`          | {}                 | 0                 | StringVal("hello %{directive}")     | # Escaped directive
      | `${true}`                      | {}                 | 0                 | True                                | # Single interpolation unwraps
      # Whitespace stripping
      | `trim ${~ "trim"}`            | {}                 | 0                 | StringVal("trimtrim")               |
      | `${"trim" ~} trim`            | {}                 | 0                 | StringVal("trimtrim")               |
      | `trim\n${~"trim"~}\ntrim`      | {}                 | 0                 | StringVal("trimtrimtrim")           |
      | ` ${~ true ~} `                | {}                 | 0                 | StringVal("true")                   | # Trim doesn't reduce to single expression if spaces remain
      | `${"hello "}${~"trim"~}${" hello"}` | {}           | 0                 | StringVal("hello trim hello")       |
      # Control sequences: if/else
      | `%{ if true ~} hello %{~ endif }` | {}              | 0                 | StringVal("hello")                  |
      | `%{ if false ~} hello %{~ endif}` | {}              | 0                 | StringVal("")                       |
      | `%{ if false ~} h %{~ else ~} g %{~ endif }` | {}    | 0                 | StringVal("g")                      |
      # Control sequences: for
      | `%{ for v in ["a","b"] }${v}%{ endfor }` | {}        | 0                 | StringVal("ab")                     |
      | `%{ for v in ["a","b"] ~} ${v} %{~ endfor }` | {}    | 0                 | StringVal("ab")                     | # Stripping with for
      | `%{ for i,v in ["a"] }${i}${v}%{ endfor }` | {}      | 0                 | StringVal("0a")                     |
      | `%{ for k,v in {"A":"a"}} ${k}${v}%{ endfor }` | {}  | 0                 | StringVal("Aa")                     | # Note: map iteration order dependent
      | `%{ for v in ["a"] }${v}${nl}%{ endfor }` | `{"nl":"\\n"}` | 0            | StringVal("a\\n")                   |
      # Invalid sequences
      | `%{ of true ~} hello %{~ endif}` | {}              | 2                 | UnknownVal(String).NotNull()        | # "of" invalid, "endif" unexpected
      | `%{ endif }`                   | {}                 | 1                 | UnknownVal(String).NotNull()        | # Unexpected endif
      # Unknowns and Marks
      | `test_${unknown}`              | `{"unknown":"?str"}`| 0               | UnknownVal(String).NotNull().Prefix("test_") | # Unknown with prefix
      | `${greeting} ${target}`       | `{"greeting":"h(m1)","target":"w(m2)"}` | 0 | StringVal("h w").Marks("m1","m2") | # greeting:"hello"(mark1), target:"world"(mark2)
      | `%{ for s in secs }${s}%{ endfor }` | `{"secs":["a","b(m1)"](mC)}` | 0 | StringVal("ab").Marks("m1","mC") | # secrets:List(StringVal("a"),StringVal("bar").Mark("m1")).Mark("mCollection")

  Scenario: Graceful handling of invalid function call in template interpolation
    Given an HCL template input string: `prefix${provider::}`
    When the template string is parsed using `ParseTemplate`
    And the parsed template expression is evaluated with a nil context
    Then the resulting cty.Value should be UnknownVal(String).NotNull()
    And diagnostics should be reported (due to invalid function call)

  Scenario: Graceful handling of invalid function call in wrapped template interpolation
    Given an HCL template input string: `${provider::}`
    When the template string is parsed using `ParseTemplate`
    And the parsed template expression is evaluated with a nil context
    Then the resulting cty.Value should be DynamicVal
    And diagnostics should be reported (due to invalid function call)

  Scenario Outline: Checking if a TemplateExpr is a simple string literal
    Given an HCL template input string: "<template_string>"
    When the template string is parsed using `ParseTemplate`
    Then no parsing diagnostics should be reported
    And the parsed TemplateExpr's `IsStringLiteral()` method should return <is_literal>

    Examples:
      | template_string | is_literal |
      | `a`             | true       |
      | `a$b`           | true       | # Escaped dollar, still literal
      | `a%%b`          | true       | # Escaped percent, still literal
      | `a\nb`          | true       | # Newline, still literal
      | `a$${\"b\"}`    | true       | # Double-escaped interpolation, effectively literal $$ and then literal {"b"}
      | `${1}`          | false      | # Single interpolation is not a string literal (unwraps)
      | `${\"b\"}`      | false      | # Single interpolation is not a string literal (unwraps)
      | `a${1}`         | false      | # Contains interpolation
      | `a${\"b\"}`     | false      | # Contains interpolation

    # Notes for tables:
    # - Variables map: JSON string like `{"varName":"value"}` or `{"varName":"?type"}` for unknown.
    #   - `?str` -> cty.UnknownVal(cty.String)
    #   - `h(m1)` -> cty.StringVal("hello").Mark("mark1")
    #   - `["a","b(m1)"](mC)` -> cty.ListVal([cty.StringVal("a"), cty.StringVal("b").Mark("m1")]).Mark("mCollection")
    # - cty.Value string: e.g., "StringVal(\"text\")", "True", "UnknownVal(String).NotNull().Prefix(\"test_\")".
    # - `IsStringLiteral` examples: `$${\"b\"}` means the template content is literally `$$` followed by `{"b"}`.
    #   The parser might break this into multiple literal parts, but `IsStringLiteral` should still consider the whole.
