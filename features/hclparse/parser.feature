# Covers functionalities in ./hclparse/parser.go

Feature: HCL Unified Parser (hclparse.Parser)
  This feature tests the `hclparse.Parser`, which provides a unified API
  for parsing HCL configurations in both native HCL syntax and HCL JSON syntax.
  It also manages a registry of parsed files to enable caching and consistent
  diagnostic reporting.

  Background:
    Given a new `hclparse.Parser` instance

  Scenario: Parsing HCL Native Syntax from byte slice
    Given a valid HCL native syntax string `foo = "bar"\n` and filename "native.hcl"
    When the parser's `ParseHCL` method is called with the string bytes and filename
    Then a non-nil `hcl.File` object should be returned
    And no diagnostics should be reported
    And the file "native.hcl" should be registered in the parser

  Scenario: Parsing HCL Native Syntax from a file
    Given a file named "test_native.hcl" with content `foo = "bar_from_file"\n`
    When the parser's `ParseHCLFile` method is called with "test_native.hcl"
    Then a non-nil `hcl.File` object should be returned
    And no diagnostics should be reported
    And the file "test_native.hcl" should be registered in the parser
    And the file's body should contain an attribute "foo" with string value "bar_from_file"

  Scenario: Parsing HCL JSON Syntax from byte slice
    Given a valid HCL JSON syntax string `{"foo": "bar_json"}\n` and filename "json.hcl"
    When the parser's `ParseJSON` method is called with the string bytes and filename
    Then a non-nil `hcl.File` object should be returned
    And no diagnostics should be reported
    And the file "json.hcl" should be registered in the parser

  Scenario: Parsing HCL JSON Syntax from a file
    Given a file named "test_json.json" with content `{"foo": "bar_from_json_file"}\n`
    When the parser's `ParseJSONFile` method is called with "test_json.json"
    Then a non-nil `hcl.File` object should be returned
    And no diagnostics should be reported
    And the file "test_json.json" should be registered in the parser
    And the file's body should contain an attribute "foo" with string value "bar_from_json_file"

  Scenario: Parser caching and diagnostic handling for repeated parsing
    Given a file named "cache_me.hcl" with content `attr = 1\n`
    When `parser.ParseHCLFile("cache_me.hcl")` is called for the first time, returning "file1" and "diags1"
    Then "diags1" should be empty
    When `parser.ParseHCLFile("cache_me.hcl")` is called for the second time, returning "file2" and "diags2"
    Then "file2" should be the same instance as "file1"
    And "diags2" should be empty
    Given a file named "error_cache.hcl" with content `attr =` (syntax error)
    When `parser.ParseHCLFile("error_cache.hcl")` is called for the first time, returning "fileE1" and "diagsE1"
    Then "diagsE1" should not be empty, containing an error diagnostic
    When `parser.ParseHCLFile("error_cache.hcl")` is called for the second time, returning "fileE2" and "diagsE2"
    Then "fileE2" should be the same instance as "fileE1"
    And "diagsE2" should be empty (diagnostics only returned on first parse)

  Scenario: Error handling when parsing a non-existent HCL file
    Given a non-existent filename "ghost.hcl"
    When the parser's `ParseHCLFile` method is called with "ghost.hcl"
    Then the returned `hcl.File` object should be nil
    And diagnostics should be reported
    And the first diagnostic summary should be "Failed to read file"
    And the first diagnostic detail should contain "could not be read"

  Scenario: Error handling when parsing a non-existent JSON file
    Given a non-existent filename "ghost.json"
    When the parser's `ParseJSONFile` method is called with "ghost.json"
    Then the returned `hcl.File` object should be nil
    And diagnostics should be reported
    And the first diagnostic summary should be "Failed to read file" # or similar from json.ParseFile
    And the first diagnostic detail should contain "could not be read"

  Scenario: Managing files with AddFile, Sources, and Files methods
    Given a parser instance
    And a pre-parsed `hcl.File` object "FileA" for filename "a.hcl" with byte content `content_a = "val_a"`
    And another `hcl.File` object "FileB" parsed by the parser from content `content_b = "val_b"` for filename "b.hcl"
    When `parser.AddFile("a.hcl", FileA)` is called
    And `parser.ParseHCL([]byte("content_b = \"val_b\""), "b.hcl")` is called (which registers FileB)
    When `parser.Files()` is called
    Then the returned map should contain "a.hcl" mapping to "FileA"
    And the returned map should contain "b.hcl" mapping to "FileB"
    When `parser.Sources()` is called
    Then the returned map should contain "a.hcl" mapping to the byte content `content_a = "val_a"`
    And the returned map should contain "b.hcl" mapping to the byte content `content_b = "val_b"`

    # Note:
    # - "file should be registered" means it's present in parser.Files().
    # - "body should contain an attribute..." implies checking the parsed content.
    # - For file operations, actual file creation/deletion would be part of step definitions.
    # - For "Managing files", the setup implies FileA.Bytes and FileB.Bytes are set correctly.
