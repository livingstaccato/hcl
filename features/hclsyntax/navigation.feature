# Covers tests in ./hclsyntax/navigation_test.go
# Specifically, TestNavigationContextString and TestNavigationContextDefRange

Feature: HCL Syntax - Navigation Context
  This feature tests the navigation capabilities within a parsed HCL file,
  specifically retrieving a human-readable context string and the definition
  range for a given byte offset in the source code.

  Background:
    Given an HCL configuration file content:
      """


      resource {
      }

      resource "random_type" {
      }

      resource "null_resource" "baz" {
        name = "foo"
        boz = {
          one = "111"
          two = "22222"
        }
      }

      data "another" "baz" {
        name = "foo"
        boz = {
          one = "111"
          two = "22222"
        }
      }
      """
    And the content is parsed into an HCL File object without diagnostics.
    And a navigation object is obtained from the parsed file.

  Scenario Outline: Retrieving context string for different byte offsets
    When the `ContextString` method of the navigation object is called with offset <Offset>
    Then the resulting context string should be "<ExpectedContext>"

    Examples:
      | Offset | ExpectedContext                 |
      | 0      | ""                              | # Start of file, before any significant token
      | 2      | ""                              | # Within leading newlines
      | 4      | "resource"                      | # Inside the first (unlabeled) "resource" block keyword
      | 17     | "resource \"random_type\""      | # Inside the "resource \"random_type\"" block keyword
      | 25     | "resource \"random_type\""      | # Inside the body of "resource \"random_type\""
      | 45     | "resource \"null_resource\" \"baz\"" | # Inside the "resource \"null_resource\" \"baz\"" block keyword
      | 142    | "data \"another\" \"baz\""        | # Inside the "data \"another\" \"baz\"" block keyword
      | 180    | "data \"another\" \"baz\""        | # Inside the "boz" attribute map within "data \"another\" \"baz\""
      | 99999  | ""                              | # Offset beyond the end of the file

  Scenario Outline: Retrieving definition range for different byte offsets
    When the `ContextDefRange` method of the navigation object is called with offset <Offset>
    Then the resulting definition hcl.Range should be Start: <StartPos>, End: <EndPos>

    Examples:
      | Offset | StartPos        | EndPos          |
      | 0      | (empty)         | (empty)         | # Start of file
      | 2      | (empty)         | (empty)         | # Within leading newlines
      | 4      | L4C1 B3         | L4C9 B11        | # "resource" block keyword
      | 17     | L7C1 B17        | L7C23 B39       | # "resource \"random_type\"" block keyword
      | 25     | L7C1 B17        | L7C23 B39       | # Body of "resource \"random_type\"" maps to its header
      | 45     | L10C1 B45       | L10C31 B75      | # "resource \"null_resource\" \"baz\"" block keyword
      | 142    | L18C1 B142      | L18C21 B162     | # "data \"another\" \"baz\"" block keyword
      | 180    | L18C1 B142      | L18C21 B162     | # "boz" attribute maps to its parent block "data \"another\" \"baz\""
      | 99999  | (empty)         | (empty)         | # Offset beyond the end of the file

    # Notes for Range table:
    # - (empty) means an hcl.Range with all zero values (empty filename, zero line/col/byte).
    # - LxCx By format: Line x, Column x, Byte y.
