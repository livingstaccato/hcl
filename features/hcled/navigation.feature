# Covers functions in ./hcled/navigation.go

Feature: HCL Editor Support - Navigation API
  This feature tests the public navigation functions in the `hcled` package,
  which provide a unified way to access contextual information about HCL code
  structures for editor and IDE integration. These functions delegate to
  parser-specific navigation logic stored in an `hcl.File`'s `Nav` field.

  Background:
    Given an `hcl.File` object named "testfile.hcl"

  Scenario: hcled.ContextString successfully delegates to file.Nav
    Given the "testfile.hcl" `Nav` field is an object that implements `contextStringer`
    And its `ContextString` method, when called with offset 10, returns "resource.my_resource.name"
    When `hcled.ContextString` is called with "testfile.hcl" and offset 10
    Then the result should be "resource.my_resource.name"

  Scenario: hcled.ContextString falls back to empty string if file.Nav does not support it
    Given the "testfile.hcl" `Nav` field is an object that does NOT implement `contextStringer`
    When `hcled.ContextString` is called with "testfile.hcl" and offset 10
    Then the result should be ""

  Scenario: hcled.ContextDefRange successfully delegates to file.Nav for a non-empty range
    Given the "testfile.hcl" `Nav` field is an object that implements `contextDefRanger`
    And its `ContextDefRange` method, when called with offset 25, returns the hcl.Range "testfile.hcl:5,3-10"
    When `hcled.ContextDefRange` is called with "testfile.hcl" and offset 25
    Then the resulting hcl.Range should be "testfile.hcl:5,3-10"

  Scenario: hcled.ContextDefRange falls back to MissingItemRange if file.Nav does not support it
    Given the "testfile.hcl" `Nav` field is an object that does NOT implement `contextDefRanger`
    And the "testfile.hcl" `Body.MissingItemRange()` returns the hcl.Range "testfile.hcl:1,1-1"
    When `hcled.ContextDefRange` is called with "testfile.hcl" and offset 25
    Then the resulting hcl.Range should be "testfile.hcl:1,1-1"

  Scenario: hcled.ContextDefRange falls back to MissingItemRange if file.Nav method returns an empty range
    Given the "testfile.hcl" `Nav` field is an object that implements `contextDefRanger`
    And its `ContextDefRange` method, when called with offset 25, returns an empty hcl.Range
    And the "testfile.hcl" `Body.MissingItemRange()` returns the hcl.Range "testfile.hcl:2,1-1"
    When `hcled.ContextDefRange` is called with "testfile.hcl" and offset 25
    Then the resulting hcl.Range should be "testfile.hcl:2,1-1"

    # Notes for table values:
    # - `contextStringer` is an internal interface with `ContextString(offset int) string`.
    # - `contextDefRanger` is an internal interface with `ContextDefRange(offset int) hcl.Range`.
    # - Ranges are represented as strings like "filename:startLine,startCol-endCol" for simplicity in Gherkin.
    # - An "empty hcl.Range" refers to a range where `IsEmpty()` would be true.
