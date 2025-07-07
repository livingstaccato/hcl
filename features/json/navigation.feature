# Covers tests in ./json/navigation_test.go
# Specifically, TestNavigationContextString

Feature: JSON File Navigation Context
  This feature tests the `ContextString` method of the navigation object
  associated with a parsed JSON file. The `ContextString` method provides
  a human-readable string describing the location/context within the JSON
  structure for a given byte offset.

  Background:
    Given a JSON source file "test.json" with the following content:
      """
      {
        "version": 1,
        "resource": {
          "null_resource": {
            "baz": {
              "id": "foo"
			},
			"boz": [
				{
					"ov": {   }
				}
			]
          }
        }
      }
      """
    And the file is parsed successfully without diagnostics.
    And a navigation object is obtained from the parsed file.

  Scenario Outline: Retrieving context string for different byte offsets
    When the `ContextString` method of the navigation object is called with offset <Offset>
    Then the resulting context string should be "<ExpectedContext>"

    Examples:
      | Offset | ExpectedContext            |
      | 0      |                            | # Beginning of the file, no specific context
      | 8      |                            | # Inside the top-level object, before "version" key ends
      | 36     | resource                   | # Inside the "resource" object value
      | 60     | resource.null_resource     | # Inside the "null_resource" object value
      | 89     | resource.null_resource.baz | # Inside the "baz" object value
      | 141    | resource.null_resource.boz | # Inside the "boz" array value (specifically, pointing to the start of the array)
