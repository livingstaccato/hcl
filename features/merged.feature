# Covers functions and types in ./merged.go
# Based on test cases in ./merged_test.go (TestMergedBodiesContent, TestMergeBodiesPartialContent)

Feature: HCL Merged Bodies
  This feature tests the functionality of merging multiple HCL Body objects
  (from `hcl.File` or directly) into a single logical Body. It focuses on how
  attributes and blocks are aggregated, how conflicts (like duplicate attributes)
  are handled, and how `Content` and `PartialContent` methods behave on the
  resulting merged body.

  Background:
    Given a list of mock HCL Body objects, where each mock body "B<n>" can be configured:
      - With a name (e.g., "first", "second") used for its diagnostic ranges.
      - To report having specific attributes (e.g., ["name", "age"]).
      - To report having specific block types and counts (e.g., {"pizza": 1, "soda": 2}).
    And an `hcl.BodySchema` "S" that defines expected attributes and blocks.

  Scenario Outline: Retrieving content from a merged body (Content method)
    Given <num_bodies> mock HCL bodies are created and configured as:
      | BodyIndex | Name    | HasAttributes | HasBlocks        |
      | 1         | <Name1> | <Attrs1>      | <Blocks1>        |
      | 2         | <Name2> | <Attrs2>      | <Blocks2>        | # If num_bodies=2
      # ... more rows for more bodies if a test case needs them
    And these bodies are merged using `hcl.MergeBodies` (or `hcl.MergeFiles` if starting from files)
    And Schema "S" is defined with Attributes: <schema_attrs_json> and Blocks: <schema_blocks_json>
    When the `Content` method is called on the merged body with Schema "S"
    Then the number of diagnostics should be <expected_diag_count>
    And the returned `hcl.BodyContent.Attributes` should contain: <expected_attrs_repr>
    And the returned `hcl.BodyContent.Blocks` should contain: <expected_blocks_repr> (types and count, origin implied by DefRange)

    Examples:
      | num_bodies | Name1   | Attrs1    | Blocks1   | Name2    | Attrs2    | Blocks2   | schema_attrs_json            | schema_blocks_json | expected_diag_count | expected_attrs_repr                 | expected_blocks_repr                     |
      | 0          |         |           |           |          |           |           | `[]`                         | `[]`               | 0                   | `{}`                                | `[]`                                     | # Empty bodies, empty schema
      | 0          |         |           |           |          |           |           | `[{"Name":"n","Req":true}]`  | `[]`               | 1                   | `{}`                                | `[]`                                     | # Required attr missing
      | 1          | "f1"    | `["n"]`   | `{}`      |          |           |           | `[{"Name":"n"}]`             | `[]`               | 0                   | `{"n":Attr("n" RangeFile:"f1")}`    | `[]`                                     |
      | 2          | "f1"    | `["n"]`   | `{}`      | "f2"     | `["n"]`   | `{}`      | `[{"Name":"n"}]`             | `[]`               | 1                   | `{"n":Attr("n" RangeFile:"f1")}`    | `[]`                                     | # Duplicate "n"
      | 2          | "f1"    | `["n"]`   | `{}`      | "f2"     | `["age"]` | `{}`      | `[{"Name":"n"},{"Name":"age"}]`| `[]`             | 0                   | `{"n":Attr("n" RF:"f1"),"age":Attr("age" RF:"f2")}` | `[]` |
      | 1          | "f1"    | `[]`      | `{"p":2}` |          |           |           | `[]`                         | `[{"Type":"p"}]`   | 0                   | `{}`                                | `[Blk("p" RF:"f1"),Blk("p" RF:"f1")]`     |
      | 2          | "f1"    | `[]`      | `{"p":1}` | "f2"     | `[]`      | `{"p":1}` | `[]`                         | `[{"Type":"p"}]`   | 0                   | `{}`                                | `[Blk("p" RF:"f1"),Blk("p" RF:"f2")]`     |

  Scenario Outline: Retrieving partial content from a merged body (PartialContent method)
    Given <num_bodies> mock HCL bodies are created and configured as:
      | BodyIndex | Name    | HasAttributes | HasBlocks        |
      | 1         | <Name1> | <Attrs1>      | <Blocks1>        |
      | 2         | <Name2> | <Attrs2>      | <Blocks2>        | # If num_bodies=2
    And these bodies are merged using `hcl.MergeBodies`
    And Schema "S" is defined with Attributes: <schema_attrs_json> and Blocks: <schema_blocks_json>
    When the `PartialContent` method is called on the merged body with Schema "S"
    Then the number of diagnostics should be <expected_diag_count>
    And the returned `hcl.BodyContent.Attributes` should contain: <expected_attrs_repr>
    And the returned `hcl.BodyContent.Blocks` should contain: <expected_blocks_repr>
    And the returned 'remaining' Body should effectively contain for "B1": Attrs <remain_attrs1>, Blocks <remain_blocks1>
    And if num_bodies=2, the 'remaining' Body should effectively contain for "B2": Attrs <remain_attrs2>, Blocks <remain_blocks2>

    Examples:
      | num_bodies | Name1 | Attrs1      | Blocks1   | Name2 | Attrs2        | Blocks2          | schema_attrs_json | schema_blocks_json | expected_diag_count | expected_attrs_repr              | expected_blocks_repr                 | remain_attrs1 | remain_blocks1 | remain_attrs2 | remain_blocks2 |
      | 0          |       |             |           |       |               |                  | `[]`              | `[]`               | 0                   | `{}`                             | `[]`                             |               |                |               |                |
      | 1          | "f1"  | `["n","a"]` | `{}`      |       |               |                  | `[{"Name":"n"}]`  | `[]`               | 0                   | `{"n":Attr("n" RF:"f1")}`        | `[]`                             | `["a"]`       | `{}`           |               |                |
      | 2          | "f1"  | `["n","a"]` | `{}`      | "f2"  | `["n","p"]`   | `{}`             | `[{"Name":"n"}]`  | `[]`               | 1                   | `{"n":Attr("n" RF:"f1")}`        | `[]`                             | `["a"]`       | `{}`           | `["p"]`       | `{}`           | # Duplicate "n"
      | 2          | "f1"  | `["n","a"]` | `{}`      | "f2"  | `["p","s"]`   | `{}`             | `[{"N":"n"},{"N":"s"}]`| `[]`             | 0                   | `{"n":Attr("n" RF:"f1"),"s":Attr("s" RF:"f2")}`| `[]`           | `["a"]`       | `{}`           | `["p"]`       | `{}`           |
      | 2          | "f1"  | `[]`        | `{"p":1}` | "f2"  | `[]`          | `{"p":1,"s":2}`  | `[]`              | `[{"Type":"p"}]`   | 0                   | `{}`                             | `[Blk("p" RF:"f1"),Blk("p" RF:"f2")]`| `[]`        | `{}`           | `[]`          | `{"s":2}`      |

  Scenario: Merged Body JustAttributes method
    Given mock HCL body "B1" with attributes `{"a":"val_a", "b":"val_b1"}` and no blocks
    And mock HCL body "B2" with attributes `{"b":"val_b2", "c":"val_c"}` and no blocks
    And "B1" and "B2" are merged
    When `JustAttributes` is called on the merged body
    Then 1 diagnostic should be reported for duplicate attribute "b"
    And the returned attributes map should contain "a" from "B1", "b" (from "B1", first one wins), and "c" from "B2"

  Scenario: EmptyBody returns an empty body
    When `hcl.EmptyBody()` is called
    And `Content` is called on the result with an empty schema
    Then the returned `hcl.BodyContent` attributes should be empty
    And the returned `hcl.BodyContent` blocks should be empty
    And no diagnostics should be reported

    # Notes for tables:
    # - `AttrsN` and `BlocksN` are JSON-like strings: `["name1","name2"]` or `{"type1":count}`.
    # - `schema_attrs_json`: e.g., `[{"Name":"attrName","Required":true}]`.
    # - `schema_blocks_json`: e.g., `[{"Type":"blockType","LabelNames":["lbl1"]}]`.
    # - `expected_attrs_repr`: e.g., `{"name":Attr("name" RangeFile:"fileName")}`. RF means Range.Filename.
    # - `expected_blocks_repr`: e.g., `[Block("type" RF:"fileName")]`.
    # - `remain_attrsN`/`remain_blocksN`: Describe the content of the effective remaining body part for body N.
    # - The mock body `testMergedBodiesVictim` is used in Go tests; this Gherkin simplifies its setup.
