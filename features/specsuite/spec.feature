# Covers tests in ./specsuite/spec_test.go
# Specifically, TestSpec which runs the HCL specification suite.

Feature: HCL Specification Suite Execution
  This feature describes the process of running the HCL specification test suite
  to ensure the HCL implementation conforms to its defined specification.

  Scenario: Running the HCL specification test suite
    Given the `hcldec` command-line tool is built from the current codebase
    And the `hclspecsuite` command-line tool is built from the current codebase
    And the HCL specification tests are located in the "specsuite/tests" directory
    When the `hclspecsuite` tool is executed with the "specsuite/tests" directory and the `hcldec` tool
    Then the suite should run to completion
    And all individual specification tests within the suite should pass
    And the `hclspecsuite` tool should report overall success (exit code 0)
    And the output should not contain any error messages for individual tests (lines indented under a test name)

  # This Gherkin scenario describes the behavior of the Go test in spec_test.go.
  # The actual detailed test cases are defined by the files within the
  # specsuite/tests directory (e.g., .hcl, .hcldec, .t files) and are
  # executed by the hclspecsuite tool. A failure in any of those underlying
  # spec tests would cause this scenario to fail.
