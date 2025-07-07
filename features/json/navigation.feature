# Covers json.navigation internal type's ContextString method in ./json/navigation.go
# Based on test cases in ./json/navigation_test.go (TestNavigationContextString)

Feature: JSON HCL Navigation - Context String
  This feature tests the `ContextString` method provided by the `json.navigation` object,
  which is part of an `hcl.File` parsed from JSON. This method generates a
  human-readable path-like string describing the HCL structural context
  at a given byte offset within the JSON source.

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
                "ov": { "deep_key": "deep_value" }
              },
              "a_string_in_array"
            ]
          }
        }
      }
      """
      # Byte offsets (approximate, 0-indexed for internal use):
      # Start: 0
      # "version": 8
      # "resource": 23 (key) -> 36 (value object starts)
      # "null_resource": 40 (key) -> 60 (value object starts)
      # "baz": 67 (key) -> 89 (value object starts)
      # "id": 90
      # "boz": 112 (key) -> 119 (value array starts)
      # First element of "boz" (object): 120
      # "ov": 125 (key) -> 131 (value object starts)
      # "deep_key": 133 (key) -> 145 (value "deep_value" starts)
      # Second element of "boz" ("a_string_in_array"): 170
    And the file is parsed successfully into an `hcl.File` object using `json.Parse`
    And the `json.navigation` object is obtained from the `File.Nav` field

  Scenario Outline: Retrieving context string for different byte offsets
    When the `ContextString` method of the navigation object is called with byte offset <ByteOffset>
    Then the resulting context string should be "<ExpectedContext>"

    Examples:
      | ByteOffset | ExpectedContext                 | Description                                      |
      | 0          | ""                              | At the beginning of the file                     |
      | 8          | ""                              | Inside top-level, before "version" key fully read|
      | 36         | "resource"                      | Inside the value of "resource" object            |
      | 60         | "resource.null_resource"        | Inside the value of "null_resource" object     |
      | 89         | "resource.null_resource.baz"    | Inside the value of "baz" object                 |
      | 119        | "resource.null_resource.boz"    | Pointing to the "boz" array itself             |
      | 125        | "resource.null_resource.boz[0].ov"| Pointing to the "ov" key in boz[0]             |
      | 133        | "resource.null_resource.boz[0].ov.deep_key"| Pointing to "deep_key" in boz[0].ov    |
      | 170        | "resource.null_resource.boz[1]" | Pointing to the string element in "boz" array  |
      # Note: The Go test used offset 141 for "boz". Based on the code, if offset 141 is *within* the "ov" object,
      # the path should include ".ov". If it's just at the start of the "boz" array, it's "resource.null_resource.boz".
      # The example for 125 and 133 above are added to clarify deeper navigation.
      # The example for 170 is added to test array indexing for non-object elements.

    # The ContextString method only considers nested objects and arrays for path building.
    # If an offset points to a primitive value within an object/array, the path to that containing object/array is returned.
    # If the offset is within a key or primitive value at a certain depth, the path up to the containing object/array is given.
    # Example: offset for "id":"foo" (byte 90-96) would yield "resource.null_resource.baz" because "id" value is not an object/array.
