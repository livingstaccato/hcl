# Covers tests in ./hclsimple/hclsimple_test.go
# Specifically, Example_nativeSyntax, Example_jsonSyntax, and TestDecodeFile

Feature: hclsimple - Simplified HCL Decoding
  This feature tests the `hclsimple` package, which provides straightforward
  functions for decoding HCL configurations into Go structs.

  Background:
    Given a Go struct `Config` defined as:
      """
      type Config struct {
          Foo string `hcl:"foo"`
          Baz string `hcl:"baz"`
      }
      """
    And a variable `config` of type `Config`.

  Scenario: Decoding HCL native syntax from a byte slice
    Given an HCL native syntax configuration string:
      """
      foo = "bar"
      baz = "boop"
      """
    When `hclsimple.Decode` is called with filename "example.hcl", the configuration bytes, nil context, and a pointer to `config`
    Then no error should be returned
    And the `config` variable should have Foo="bar" and Baz="boop"

  Scenario: Decoding HCL JSON syntax from a byte slice
    Given an HCL JSON syntax configuration string:
      """
      {
          "foo": "bar",
          "baz": "boop"
      }
      """
    When `hclsimple.Decode` is called with filename "example.json", the configuration bytes, nil context, and a pointer to `config`
    Then no error should be returned
    And the `config` variable should have Foo="bar" and Baz="boop"

  Scenario: Decoding an HCL native syntax file
    Given a file named "testdata/test.hcl" with the content:
      """
      foo = "bar"
      baz = "boop"
      """
    When `hclsimple.DecodeFile` is called with the path "testdata/test.hcl", nil context, and a pointer to `config`
    Then no error should be returned
    And the `config` variable should have Foo="bar" and Baz="boop"
