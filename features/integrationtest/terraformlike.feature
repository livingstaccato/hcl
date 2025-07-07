# Covers tests in ./integrationtest/terraformlike_test.go
# Specifically, TestTerraformLike (for both native and JSON syntax)

Feature: Terraform-like HCL Configuration Processing
  This feature tests the parsing, decoding, and evaluation of HCL configurations
  that mimic the structure and complexity of Terraform. It covers variables,
  resources (including dynamic blocks and dependencies), modules, and locals,
  for both HCL native and JSON syntaxes.

  Background:
    Given a set of Go structs (`Root`, `Variable`, `Resource`, `Module`, `Locals`) to represent the Terraform-like config
    And HCLdec specs for "happycloud_instance" (attributes: image_id, instance_type, tags)
    And HCLdec specs for "happycloud_security_group" (block list: ingress with cidr_block attribute)
    And an EvalContext available for providing variables and functions

  Scenario Outline: Processing a Terraform-like configuration in <SyntaxType>
    Given a Terraform-like configuration in <SyntaxType> format:
      """
      <config_content>
      """
      # <config_content> is either terraformLikeNativeSyntax or terraformLikeJSON from the Go test
    When the configuration is parsed using the appropriate HCL parser for <SyntaxType>
    Then no parsing diagnostics should be reported
    When the parsed HCL body is decoded into the Root Go struct using `gohcl.DecodeBody`
    Then no root decoding diagnostics should be reported

    # Variable block assertions
    And the Root struct should contain 1 "variable" block
    And the first "variable" block should have Name "image_id"

    # Resource block assertions (sorted by name: private, public, test)
    And the Root struct should contain 3 "resource" blocks
    # Resource 1: happycloud_security_group "private"
    And the first resource block (named "private") should have Type "happycloud_security_group"
      Given an EvalContext with "var.extra_private_cidr_blocks" as `["172.16.0.0/12", "169.254.0.0/16"]`
      When its HCL Body `Config` is expanded for dynamic blocks using `dynblock.Expand`
      And the expanded body is decoded using the "happycloud_security_group" hcldec spec
      Then no resource decoding diagnostics should be reported
      And its "ingress" attribute (a list of objects) should contain:
        | cidr_block     |
        | "10.0.0.0/8"   |
        | "192.168.0.0/16"|
        | "172.16.0.0/12"| # From dynamic block
        | "169.254.0.0/16"| # From dynamic block
    # Resource 2: happycloud_security_group "public"
    And the second resource block (named "public") should have Type "happycloud_security_group"
      When its HCL Body `Config` is decoded using the "happycloud_security_group" hcldec spec
      Then no resource decoding diagnostics should be reported
      And its "ingress" attribute should contain:
        | cidr_block |
        | "0.0.0.0/0"|
    # Resource 3: happycloud_instance "test"
    And the third resource block (named "test") should have Type "happycloud_instance"
      When `hcldec.Variables` is called on its HCL Body `Config` for attribute "image_id" (String)
      Then it should identify 1 variable traversal with root name "var"
      Given an EvalContext with "var.image_id" as "image-1234"
      When its HCL Body `Config` is decoded using the "happycloud_instance" hcldec spec and the context
      Then no resource decoding diagnostics should be reported
      And its "instance_type" attribute should be "z3.weedy"
      And its "image_id" attribute should be "image-1234"
      And its "tags" attribute (a map) should be `{"Name": "foo", "Environment": "prod"}`
      When its `DependsOn` hcl.Expression is parsed as an expression list
      Then it should contain 1 expression
      And when the first expression in `DependsOn` is parsed as an absolute traversal
      Then the traversal should have 2 steps with root name "happycloud_security_group" and attribute "public"

    # Module block assertions
    And the Root struct should contain 1 "module" block
    And the first "module" block should have Name "foo"
      When its `Providers` hcl.Expression is parsed as an expression map
      Then it should contain 1 key-value pair
      And for the first pair, the key expression should be an absolute traversal for "null"
      And for the first pair, the value expression should be an absolute traversal for "null.foo"

    # Locals block assertions
    And the Root struct should contain 1 "locals" block
      Given an EvalContext with function "func" returning "func_result" and "scoped::func" returning "scoped::func_result"
      When attributes are extracted from the first "locals" block's HCL Body `Config`
      And the "func_result" attribute expression is evaluated with the context
      Then its value should be "func_result"
      And when the "scoped_func_result" attribute expression is evaluated with the context
      Then its value should be "scoped::func_result"

    Examples:
      | SyntaxType    | config_content                                              |
      | Native Syntax | (content of terraformLikeNativeSyntax variable in Go test)  |
      | JSON          | (content of terraformLikeJSON variable in Go test)          |

    # Notes for table values:
    # - `<config_content>` placeholders refer to the large string constants in the Go test.
    # - cty.Value representations are simplified (e.g., `["val1", "val2"]`).
    # - Traversal descriptions are simplified (e.g., "root.attr").
    # - The order of resources is after sorting by name as done in the Go test.
