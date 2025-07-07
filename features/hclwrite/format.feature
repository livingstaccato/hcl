# Covers tests in ./hclwrite/format_test.go
# Specifically, TestFormat and TestLinesForFormat

Feature: HCL Write - Formatting
  This feature tests the HCL code formatting capabilities of the `hclwrite` package.
  It ensures that various HCL constructs, once lexed into tokens, are formatted
  into a canonical, readable string representation. This includes spacing around
  operators, indentation, alignment of attributes, and handling of comments and
  different HCL structures like expressions, blocks, and templates.

  Scenario Outline: Formatting HCL token streams
    Given an HCL input string:
      """
      <input_hcl>
      """
    When the input is lexed into tokens
    And the `format` function is applied to these tokens
    Then the byte representation of the formatted tokens should be:
      """
      <expected_formatted_hcl>
      """

    Examples:
      | input_hcl                               | expected_formatted_hcl                |
      | `""`                                    | `""`                                  | # Empty
      | `a=1`                                   | `a = 1`                               | # Simple assignment
      | `a=b.c`                                 | `a = b.c`                             | # Traversal
      | `a=b[c]`                                | `a = b[c]`                             | # Indexing
      | `( a+2 )`                               | `(a + 2)`                             | # Binary op with parens
      | `( a*-2 )`                              | `(a * -2)`                            | # Multiply by negative
      | `foo(1, -2,a*b, b,c)`                   | `foo(1, -2, a * b, b, c)`             | # Function call
      | `a="hello ${ name }"`                  | `a = "hello ${name}"`                 | # String template
      | `a="hello ${~ name ~}"`                 | `a = "hello ${~name~}"`               | # String template with trim
      | `b{}`                                   | `b {}`                                | # Block
      | `\n"${hello\n}"\n`                      | `\n"${  hello\n}"\n`                  | # Multiline string indent
      | `a?b:c`                                 | `a ? b : c`                           | # Conditional
      | `[for x in y : x]`                      | `[for x in y : x]`                    | # For expression
      | `\n[[\na\n]]\n`                         | `\n[[\n  a\n]]\n`                     | # Nested list indent
      | `\nb {\na = 1\n}\n`                     | `\nb {\n  a = 1\n}\n`                 | # Block content indent
      | `\na = 1\nbungle = 2\n`                 | `\na      = 1\nbungle = 2\n`          | # Attribute alignment
      | `\na = 1 # foo\nbungle = "bonce" # baz\n`| `\na      = 1       # foo\nbungle = "bonce" # baz\n` | # Alignment with comments
      | `\nfoo {\n# ...\n}\n`                   | `\nfoo {\n  # ...\n}\n`               | # Comment indent in block
      | `\nfoo = {\n# ...\n}\n`                 | `\nfoo = {\n  # ...\n}\n`               | # Comment indent in object
      | `\nfoo = [\n# ...\n]\n`                 | `\nfoo = [\n  # ...\n]\n`               | # Comment indent in list
      | `\nfoo {\nbar = <<-EOT\n  Foo\nEOT\n}\n` | `\nfoo {\n  bar = <<-EOT\n  Foo\nEOT\n}\n` | # Heredoc indent
      | `attr = provider::framework::example()` | `attr = provider::framework::example()` | # Namespaced function call
      | `attr = provider :: framework :: example()`| `attr = provider::framework::example()`| # Namespaced func with spaces

  Scenario Outline: Grouping tokens into lines for formatting (linesForFormat)
    Given a sequence of HCL tokens: <token_sequence_description>
    When `linesForFormat` is called with these tokens
    Then the resulting `[]formatLine` should be structured as:
      | Line | Lead Tokens                       | Assign Tokens                      | Comment Tokens              |
      # The table below will be populated by examples
      <expected_format_lines>

    Examples:
      | token_sequence_description                               | expected_format_lines                                                                                                      |
      | `EOF`                                                    | L0: Lead:[] Assign:[] Comment:[]                                                                                           |
      | `Ident EOF`                                              | L0: Lead:[Ident] Assign:[] Comment:[]                                                                                      |
      | `Ident NL Num EOF`                                       | L0: Lead:[Ident,NL] Assign:[] Comment:[] <br> L1: Lead:[Num] Assign:[] Comment:[]                                           |
      | `Ident Comment(#foo\n) Num EOF`                          | L0: Lead:[Ident] Assign:[] Comment:[Comment(#foo\n)] <br> L1: Lead:[Num] Assign:[] Comment:[]                               |
      | `Ident Eq Num EOF`                                       | L0: Lead:[Ident] Assign:[Eq,Num] Comment:[]                                                                                |
      | `Ident Eq Num Comment(#foo\n) EOF`                       | L0: Lead:[Ident] Assign:[Eq,Num] Comment:[Comment(#foo\n)] <br> L1: Lead:[] Assign:[] Comment:[]                            |
      | `Comment(#foo\n) EOF`                                    | L0: Lead:[Comment(#foo\n)] Assign:[] Comment:[] <br> L1: Lead:[] Assign:[] Comment:[]                                      | # Whole-line comment

    # Notes for tables:
    # - Input HCL for `TestFormat` is provided as a single string, newlines are significant.
    # - Expected formatted HCL also a single string, newlines significant.
    # - Token sequence for `TestLinesForFormat` is a list of hclsyntax.Token types (Ident, NL, Num, Comment, Eq, EOF).
    # - `formatLine` structure: `Lead:[Tokens] Assign:[Tokens] Comment:[Tokens]`.
    # - `<br>` is used in the Gherkin table to represent multiple `formatLine` entries for readability.
    # - Bytes of tokens are implied unless specified (e.g., Comment(#foo\n)).
