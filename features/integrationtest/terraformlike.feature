# Covers tests in ./integrationtest/terraformlike_test.go
# Specifically, TestTerraformLike (for both native and JSON syntax)

Feature: Terraform-like Configuration Processing
  This feature tests the parsing and decoding of HCL configurations
  that mimic the structure and complexity of Terraform, covering
  variables, resources (including dynamic blocks), modules, and locals.
  It ensures that both native HCL syntax and JSON HCL syntax are processed correctly.

  Background:
    Given a Terraform-like configuration structure with:
      - `variable` blocks
      - `resource` blocks (supporting `depends_on` and dynamic content)
      - `module` blocks (supporting `providers`)
      - `locals` blocks (supporting function calls)
    And specific decoding specs for "happycloud_instance" and "happycloud_security_group" resources.

  Scenario Outline: Processing Terraform-like configuration in <SyntaxType>
    Given a Terraform-like configuration is provided in <SyntaxType> format
    When the configuration is parsed
    Then no parsing diagnostics should be reported
    When the parsed body is decoded into the root structure
    Then no root evaluation diagnostics should be reported
    And the decoded 'variable' blocks should be:
      | Name     |
      | image_id |
    And there should be 3 'resource' blocks
    And the "happycloud_security_group" resource named "private" should:
      Given an evaluation context with "var.extra_private_cidr_blocks" as ["172.16.0.0/12", "169.254.0.0/16"]
      When its configuration body is expanded for dynamic blocks
      And decoded using the security group spec
      Then no decoding diagnostics should be reported
      And its "ingress" list should contain:
        | cidr_block     |
        | 10.0.0.0/8     |
        | 192.168.0.0/16 |
        | 172.16.0.0/12  |
        | 169.254.0.0/16 |
    And the "happycloud_security_group" resource named "public" should:
      When its configuration body is decoded using the security group spec
      Then no decoding diagnostics should be reported
      And its "ingress" list should contain:
        | cidr_block |
        | 0.0.0.0/0  |
    And the "happycloud_instance" resource named "test" should:
      Given an evaluation context with "var.image_id" as "image-1234"
      When its configuration body is decoded using the instance spec
      Then no decoding diagnostics should be reported
      And its "image_id" attribute should be "image-1234"
      And its "instance_type" attribute should be "z3.weedy"
      And its "tags" attribute should be a map with "Name": "foo" and "Environment": "prod"
      And its "depends_on" attribute should refer to "happycloud_security_group.public"
    And there should be 1 'module' block
    And the module named "foo" should:
      When its "providers" attribute is parsed as an expression map
      Then no parsing diagnostics should be reported
      And it should contain one entry where the key is "null" and the value refers to "null.foo"
    And the 'locals' block should:
      Given an evaluation context with functions "func" (returning "func_result") and "scoped::func" (returning "scoped::func_result")
      When its attributes are evaluated
      Then the "func_result" attribute should be "func_result"
      And the "scoped_func_result" attribute should be "scoped::func_result"

    Examples:
      | SyntaxType    |
      | Native Syntax |
      | JSON          |
