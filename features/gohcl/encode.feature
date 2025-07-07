# Covers tests in ./gohcl/encode_test.go
# Specifically, ExampleEncodeIntoBody

Feature: gohcl - Encoding Go Structs into HCL
  This feature tests the `EncodeIntoBody` function from the `gohcl` package,
  which serializes Go structs into an HCL configuration body using `hclwrite`.

  Scenario: Encoding a nested Go struct into HCL
    Given Go struct definitions for `App`, `Constraints`, and `Service`:
      """
      type Service struct {
          Name string   `hcl:"name,label"`
          Exe  []string `hcl:"executable"`
      }
      type Constraints struct {
          OS   string `hcl:"os"`
          Arch string `hcl:"arch"`
      }
      type App struct {
          Name        string       `hcl:"name"`
          Desc        string       `hcl:"description"`
          Constraints *Constraints `hcl:"constraints,block"`
          Services    []Service    `hcl:"service,block"`
      }
      """
    And an instance of the `App` struct populated as follows:
      Name: "awesome-app"
      Desc: "Such an awesome application"
      Constraints:
        OS: "linux"
        Arch: "amd64"
      Services:
        - Name: "web"
          Exe: ["./web", "--listen=:8080"]
        - Name: "worker"
          Exe: ["./worker"]
    And an empty `hclwrite.File` named `f`
    When `gohcl.EncodeIntoBody` is called with the `App` instance and `f.Body()`
    Then the HCL content of `f.Bytes()` should be:
      """
      name        = "awesome-app"
      description = "Such an awesome application"

      constraints {
        os   = "linux"
        arch = "amd64"
      }

      service "web" {
        executable = ["./web", "--listen=:8080"]
      }
      service "worker" {
        executable = ["./worker"]
      }
      """
    # Note: The Go test uses fmt.Printf("%s", f.Bytes()), so exact string matching,
    # including newlines and indentation, is expected.tool_code
File 'features/gohcl/encode.feature' created successfully.
