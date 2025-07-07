# Covers tests in ./ext/dynblock/variables_test.go
# Specifically, TestVariables (WalkVariables and WalkExpandVariables)

Feature: Dynamic Block Variable Extraction
  This feature tests how variables are identified within HCL configurations
  that include dynamic blocks, using both full variable walking and
  expansion-only variable walking.

  Background:
    Given an HCL configuration with nested static and dynamic blocks:
      """
      # Static 'a' block containing a dynamic 'b' block
      a {
        dynamic "b" {
          for_each = [for i, v in some_list_0: "${i}=${v},${baz}"] # References: some_list_0, baz
          labels = ["${b.value} ${something_else_0}"]              # References: b (iterator), something_else_0
          content {
            val = "${b.value} ${something_else_1}"                 # References: b (iterator), something_else_1
          }
        }
      }

      # Top-level dynamic 'a' block
      dynamic "a" {
        for_each = some_list_1                                      # References: some_list_1
        content {
          # Static 'b' block inside dynamic 'a'
          b "foo" {
            val = "${a.value} ${something_else_2}"                 # References: a (iterator), something_else_2
          }

          # Dynamic 'b' block inside dynamic 'a'
          dynamic "b" {
            for_each = some_list_2                                  # References: some_list_2
            iterator = dyn_b
            labels = ["${a.value} ${dyn_b.value} ${b} ${something_else_3}"] # References: a (iterator), dyn_b (iterator), b (var), something_else_3
            content {
              val = "${a.value} ${dyn_b.value} ${something_else_4}" # References: a (iterator), dyn_b (iterator), something_else_4
            }
          }
        }
      }

      # Another top-level dynamic 'a' block with different iterator name
      dynamic "a" {
        for_each = some_list_3                                      # References: some_list_3
        iterator = dyn_a
        content {
          # Static 'b' block inside dynamic 'a'
          b "foo" {
            val = "${dyn_a.value} ${something_else_5}"               # References: dyn_a (iterator), something_else_5
          }

          # Dynamic 'b' block inside dynamic 'a'
          dynamic "b" {
            for_each = some_list_4                                  # References: some_list_4
            # Implicit iterator 'b' for this dynamic block
            labels = ["${dyn_a.value} ${b.value} ${a} ${something_else_6}"] # References: dyn_a (iterator), b (iterator), a (var), something_else_6
            content {
              val = "${dyn_a.value} ${b.value} ${something_else_7}" # References: dyn_a (iterator), b (iterator), something_else_7
            }
          }
        }
      }
      """
    And an HCLdec spec for a list of 'a' blocks, where each 'a' block contains a map of 'b' blocks, and each 'b' block has a 'val' attribute of type string.

  Scenario: Walking all variables (VariablesHCLDec)
    When `VariablesHCLDec` is used to find all variable traversals in the configuration body with the given spec
    Then the root names of the identified traversals, in order, should be:
      | root_name        |
      | some_list_1      |
      | some_list_3      |
      | some_list_0      |
      | baz              |
      | something_else_0 |
      | something_else_1 | # From content of first dynamic "b"
      | some_list_2      |
      | b                | # Variable 'b', shadowed by iterator 'dyn_b' in labels but not content
      | something_else_3 |
      | something_else_2 | # From content of static "b" in first dynamic "a"
      | something_else_4 | # From content of second dynamic "b" in first dynamic "a"
      | some_list_4      |
      | a                | # Variable 'a', shadowed by iterator 'dyn_a' in labels but not content
      | something_else_6 |
      | something_else_5 | # From content of static "b" in second dynamic "a"
      | something_else_7 | # From content of second dynamic "b" in second dynamic "a"

  Scenario: Walking only variables needed for expansion (ExpandVariablesHCLDec)
    When `ExpandVariablesHCLDec` is used to find variable traversals needed for block expansion in the configuration body with the given spec
    Then the root names of the identified traversals, in order, should be:
      | root_name        |
      | some_list_1      | # for_each of first dynamic "a"
      | some_list_3      | # for_each of second dynamic "a"
      | some_list_0      | # for_each of dynamic "b" in static "a"
      | baz              | # in for_each of dynamic "b" in static "a"
      | something_else_0 | # in labels of dynamic "b" in static "a"
      # something_else_1 is NOT included (only in content)
      | some_list_2      | # for_each of dynamic "b" in first dynamic "a"
      | b                | # in labels of dynamic "b" in first dynamic "a" (var 'b')
      | something_else_3 | # in labels of dynamic "b" in first dynamic "a"
      # something_else_2 is NOT included (only in content)
      # something_else_4 is NOT included (only in content)
      | some_list_4      | # for_each of dynamic "b" in second dynamic "a"
      | a                | # in labels of dynamic "b" in second dynamic "a" (var 'a')
      | something_else_6 | # in labels of dynamic "b" in second dynamic "a"
      # something_else_5 is NOT included (only in content)
      # something_else_7 is NOT included (only in content)
