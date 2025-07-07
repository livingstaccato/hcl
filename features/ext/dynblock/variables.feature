# Covers functions in ./ext/dynblock/variables_hcldec.go and ./ext/dynblock/variables.go
# Based on test cases in ./ext/dynblock/variables_test.go

Feature: Dynamic Block Variable Extraction with HCLDec Specs
  This feature tests the `VariablesHCLDec` and `ExpandVariablesHCLDec` functions,
  which identify variable traversals in HCL configurations containing dynamic blocks,
  guided by an `hcldec.Spec`. `VariablesHCLDec` finds all variables used by the spec,
  including those inside dynamic block content. `ExpandVariablesHCLDec` finds only
  variables needed for the expansion of dynamic blocks (from `for_each` and `labels`).

  Background:
    Given an HCL configuration with nested static and dynamic blocks:
      """
      # Static 'a' block containing a dynamic 'b' block
      a {
        dynamic "b" {
          for_each = [for i, v in some_list_0: "${i}=${v},${baz}"] # Refs: some_list_0, baz
          labels = ["${b.value} ${something_else_0}"]              # Refs: b (iterator), something_else_0
          content {
            val = "${b.value} ${something_else_1}"                 # Refs: b (iterator), something_else_1
          }
        }
      }

      # Top-level dynamic 'a' block
      dynamic "a" {
        for_each = some_list_1                                      # Refs: some_list_1
        content {
          # Static 'b' block inside dynamic 'a'
          b "foo" {
            val = "${a.value} ${something_else_2}"                 # Refs: a (iterator), something_else_2
          }

          # Dynamic 'b' block inside dynamic 'a'
          dynamic "b" {
            for_each = some_list_2                                  # Refs: some_list_2
            iterator = dyn_b
            labels = ["${a.value} ${dyn_b.value} ${b} ${something_else_3}"] # Refs: a (iter), dyn_b (iter), b (var), something_else_3
            content {
              val = "${a.value} ${dyn_b.value} ${something_else_4}" # Refs: a (iter), dyn_b (iter), something_else_4
            }
          }
        }
      }

      # Another top-level dynamic 'a' block with different iterator name
      dynamic "a" {
        for_each = some_list_3                                      # Refs: some_list_3
        iterator = dyn_a
        content {
          # Static 'b' block inside dynamic 'a'
          b "foo" {
            val = "${dyn_a.value} ${something_else_5}"               # Refs: dyn_a (iter), something_else_5
          }

          # Dynamic 'b' block inside dynamic 'a'
          dynamic "b" {
            for_each = some_list_4                                  # Refs: some_list_4
            # Implicit iterator 'b' for this dynamic block
            labels = ["${dyn_a.value} ${b.value} ${a} ${something_else_6}"] # Refs: dyn_a (iter), b (iter), a (var), something_else_6
            content {
              val = "${dyn_a.value} ${b.value} ${something_else_7}" # Refs: dyn_a (iter), b (iter), something_else_7
            }
          }
        }
      }
      """
    And an HCLdec Spec defined as:
      A BlockListSpec for type "a", with a Nested BlockMapSpec for type "b" (label "key"),
      which in turn has a Nested AttrSpec for "val" of type String.
      # This spec implies we care about 'a' blocks, and within them 'b' blocks, and within 'b' blocks the 'val' attribute.

  Scenario: Extracting all variables referenced by the spec (VariablesHCLDec)
    When `VariablesHCLDec` is called with the parsed HCL body and the defined Spec
    Then the root names of the identified variable traversals, in order, should be:
      | root_name        |
      | some_list_1      | # From top-level dynamic "a" for_each
      | some_list_3      | # From second top-level dynamic "a" for_each
      | some_list_0      | # From for_each of dynamic "b" inside static "a"
      | baz              | # From for_each of dynamic "b" inside static "a" (via list comprehension)
      | something_else_0 | # From labels of dynamic "b" inside static "a"
      | something_else_1 | # From content.val of dynamic "b" inside static "a"
      | some_list_2      | # From for_each of dynamic "b" inside first dynamic "a"
      | b                | # From labels of dynamic "b" inside first dynamic "a" (variable 'b', not iterator 'dyn_b')
      | something_else_3 | # From labels of dynamic "b" inside first dynamic "a"
      | something_else_2 | # From content.val of static "b" inside first dynamic "a"
      | something_else_4 | # From content.val of dynamic "b" inside first dynamic "a"
      | some_list_4      | # From for_each of dynamic "b" inside second dynamic "a"
      | a                | # From labels of dynamic "b" inside second dynamic "a" (variable 'a', not iterator 'dyn_a')
      | something_else_6 | # From labels of dynamic "b" inside second dynamic "a"
      | something_else_5 | # From content.val of static "b" inside second dynamic "a"
      | something_else_7 | # From content.val of dynamic "b" inside second dynamic "a"

  Scenario: Extracting only variables needed for dynamic block expansion (ExpandVariablesHCLDec)
    When `ExpandVariablesHCLDec` is called with the parsed HCL body and the defined Spec
    Then the root names of the identified variable traversals, in order, should be:
      | root_name        |
      | some_list_1      | # From top-level dynamic "a" for_each
      | some_list_3      | # From second top-level dynamic "a" for_each
      | some_list_0      | # From for_each of dynamic "b" inside static "a"
      | baz              | # From for_each of dynamic "b" inside static "a"
      | something_else_0 | # From labels of dynamic "b" inside static "a"
      # something_else_1 is NOT included (only in content of dynamic "b")
      | some_list_2      | # From for_each of dynamic "b" inside first dynamic "a"
      | b                | # From labels of dynamic "b" inside first dynamic "a" (variable 'b')
      | something_else_3 | # From labels of dynamic "b" inside first dynamic "a"
      # something_else_2 is NOT included (only in content of static "b")
      # something_else_4 is NOT included (only in content of dynamic "b")
      | some_list_4      | # From for_each of dynamic "b" inside second dynamic "a"
      | a                | # From labels of dynamic "b" inside second dynamic "a" (variable 'a')
      | something_else_6 | # From labels of dynamic "b" inside second dynamic "a"
      # something_else_5 is NOT included (only in content of static "b")
      # something_else_7 is NOT included (only in content of dynamic "b")

    # Note: The order of variables in the "expected_variable_root_names" list is significant and
    # reflects the traversal order implemented in the Go code (top-level dynamic blocks first,
    # then nested dynamic blocks, attributes within content last for VariablesHCLDec).
    # Iterator variables (like 'b.value', 'a.value', 'dyn_b.value', 'dyn_a.value') are local to the
    # dynamic block's context and are not reported as external variables.
    # Variables referenced in parts of the HCL not covered by the Spec are ignored.
