# Covers examples in ./hclwrite/examples_test.go
# Specifically, Example_generateFromScratch and ExampleExpression_RenameVariablePrefix

Feature: HCL Write Package Examples
  This feature demonstrates common use-cases of the `hclwrite` package,
  showcasing how to programmatically generate and modify HCL configurations.

  Scenario: Generating an HCL configuration from scratch
    Given an empty `hclwrite.File`
    When the following operations are performed on its root body:
      | Action                   | Name/Type | Labels/Value/Traversal | Details (if any)                                   |
      | SetAttributeValue        | "string"  | StringVal("bar")       |                                                    |
      | AppendNewline            |           |                        |                                                    |
      | SetAttributeValue        | "object"  | ObjectVal              | {foo:Str("foo"), bar:Num(5), baz:True}             |
      | SetAttributeValue        | "string"  | StringVal("foo")       |                                                    | # Overwrites previous "string"
      | SetAttributeValue        | "bool"    | False                  |                                                    |
      | SetAttributeTraversal    | "path"    | Traversal("env.PATH")  |                                                    |
      | AppendNewline            |           |                        |                                                    |
      | AppendNewBlock           | "foo"     | []                     | Returns `fooBlock`                                 |
      | AppendNewBlock           | "empty"   | []                     |                                                    |
      | AppendNewline            |           |                        |                                                    |
      | AppendNewBlock           | "bar"     | ["a", "b"]             | Returns `barBlock`                                 |
    And on `fooBlock.Body()`:
      | Action                   | Name      | Value                  |
      | SetAttributeValue        | "hello"   | StringVal("world")     |
    And on `barBlock.Body()`:
      | Action                   | Name/Type | Labels                 | Details (if any)                                   |
      | AppendNewBlock           | "baz"     | []                     | Returns `bazBlock`                                 |
    And on `bazBlock.Body()`:
      | Action                   | Name      | Value                  |
      | SetAttributeValue        | "foo"     | NumberIntVal(10)       |
      | SetAttributeValue        | "beep"    | StringVal("boop")      |
      | SetAttributeValue        | "baz"     | ListValEmpty(String)   |
    Then the byte representation of the `hclwrite.File` should be:
      """
      string = "foo"

      object = {
        bar = 5
        baz = true
        foo = "foo"
      }
      bool = false
      path = env.PATH

      foo {
        hello = "world"
      }
      empty {
      }

      bar "a" "b" {
        baz {
          foo  = 10
          beep = "boop"
          baz  = []
        }
      }
      """

  Scenario: Renaming variable prefixes in expressions
    Given an HCL configuration parsed from the string:
      """
      foo = a.x + a.y * b.c
      bar = max(a.z, b.c)
      """
    And no parsing diagnostics are reported
    When for each attribute in the file's body, its expression's `RenameVariablePrefix` method is called to change "a" to "z"
    Then the byte representation of the modified `hclwrite.File` should be:
      """
      foo = z.x + z.y * b.c
      bar = max(z.z, b.c)
      """

    # Notes for tables:
    # - Value/Traversal representations are simplified (e.g., StringVal("bar"), Traversal("env.PATH")).
    # - ObjectVal details show the map structure.
    # - The output for "Generating HCL" includes specific formatting (newlines, indentation) as produced by hclwrite.
