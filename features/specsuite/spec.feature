# Covers tests in ./specsuite/spec_test.go
# Specifically, TestSpec which runs the HCL specification suite.

Feature: HCL Specification Suite Conformance
  This feature describes the execution of the HCL specification test suite,
  which validates the HCL implementation (parsing, decoding via hcldec)
  against a predefined set of test cases covering various aspects of the
  HCL language and its JSON representation.

  Scenario: Running the HCL specification test suite successfully
    Given the `hcldec` command-line tool is successfully built from the current HCLv2 codebase
    And the `hclspecsuite` command-line tool (test harness) is successfully built from the current HCLv2 codebase
    And the HCL specification test files are located in the "specsuite/tests" directory
    When the `hclspecsuite` harness is executed with the "specsuite/tests" directory and the built `hcldec` tool
    Then the `hclspecsuite` harness should complete successfully (exit code 0)
    And the output from the harness should not indicate any failures for individual specification tests
      # This means no lines starting with "- test_name" followed by error messages.

    # Note: The actual HCL features (like comment parsing, expression evaluation, block structures)
    # are defined by the individual test files (.hcl, .hcldec, .json, .t) within the "specsuite/tests" directory.
    # This Gherkin scenario verifies that the entire suite, when run by the harness, passes,
    # indicating conformance to those detailed specifications. Failures in underlying spec tests
    # would cause the harness to report errors and/or exit with a non-zero code.
