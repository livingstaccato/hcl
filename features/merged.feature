# Covers tests in ./merged_test.go
# Specifically, TestMergedBodiesContent and TestMergeBodiesPartialContent

Feature: Merged HCL Bodies
  This feature tests the behavior of `MergeBodies`, which combines multiple
  HCL Body objects into a single logical Body. It focuses on how `Content`
  and `PartialContent` methods behave on such merged bodies, particularly
  regarding attribute and block resolution, and diagnostic reporting.

  Background:
    Given a set of HCL Body objects to be merged.
    And each body object can be a `testMergedBodiesVictim` which simulates:
      - A `Name` (used for filename in ranges to identify origin).
      - A list of attribute names it `HasAttributes`.
      - A map of block types to counts it `HasBlocks`.
      - A `DiagCount` for diagnostics it would produce.
    And attributes/blocks from these victims have their `NameRange` or `DefRange` (respectively)
    set to a range with `Filename` equal to the victim's `Name`.

  Scenario Outline: Merged Body Content retrieval
    Given <num_bodies> HCL bodies are defined as:
      | BodyIndex | Name   | HasAttributes | HasBlocks        | DiagCount |
      | 1         | <Name1>| <Attrs1>      | <Blocks1>        | <Diags1>  |
      | 2         | <Name2>| <Attrs2>      | <Blocks2>        | <Diags2>  | # If num_bodies is 2
      # ... potentially more for other tests, this table structure is illustrative
    And these bodies are merged using `MergeBodies`.
    And a BodySchema is defined with:
      | type              | schema_details          |
      | attributes        | <attrs_schema>          |
      | blocks            | <blocks_schema>         |
    When the `Content` method is called on the merged body with the schema
    Then the number of diagnostics should be <expected_total_diag_count>
    And the returned BodyContent should have:
      | type              | content_details         |
      | attributes        | <expected_attrs>        |
      | blocks            | <expected_blocks>       |

    Examples:
      # Empty cases
      | num_bodies | Name1   | Attrs1    | Blocks1   | Diags1 | Name2   | Attrs2    | Blocks2   | Diags2 | attrs_schema                  | blocks_schema | expected_total_diag_count | expected_attrs | expected_blocks |
      | 0          |         |           |           |        |         |           |           |        | (empty)                       | (empty)       | 0                         | {}             | (empty)         |
      | 0          |         |           |           |        |         |           |           |        | [{name:"name"}]               | (empty)       | 0                         | {}             | (empty)         |
      | 0          |         |           |           |        |         |           |           |        | [{name:"name", required:true}]| (empty)       | 1                         | {}             | (empty)         |
      # Single body
      | 1          | "first" | ["name"]  | {}        | 0      |         |           |           |        | [{name:"name"}]               | (empty)       | 0                         | {name:Attr("name" Range(first))} | (empty)   |
      # Attribute merging
      | 2          | "first" | ["name"]  | {}        | 0      | "second"| ["name"]  | {}        | 0      | [{name:"name"}]               | (empty)       | 1                         | {name:Attr("name" Range(first))} | (empty)   | # Duplicate attribute
      | 2          | "first" | ["name"]  | {}        | 0      | "second"| ["age"]   | {}        | 0      | [{name:"name"},{name:"age"}]  | (empty)       | 0                         | {name:Attr("name" Range(first)), age:Attr("age" Range(second))} | (empty) |
      # Block merging
      | 0          |         |           |           |        |         |           |           |        | (empty)                       | [{type:"pizza"}] | 0                       | {}             | (empty)         |
      | 1          | "first" | []        | {pizza:1} | 0      |         |           |           |        | (empty)                       | [{type:"pizza"}] | 0                       | {}             | [Block("pizza" Range(first))] |
      | 1          | "first" | []        | {pizza:2} | 0      |         |           |           |        | (empty)                       | [{type:"pizza"}] | 0                       | {}             | [Block("pizza" Range(first)), Block("pizza" Range(first))] |
      | 2          | "first" | []        | {pizza:1} | 0      | "second"| []        | {pizza:1} | 0      | (empty)                       | [{type:"pizza"}] | 0                       | {}             | [Block("pizza" Range(first)), Block("pizza" Range(second))] |
      | 2          | "first" | []        | {}        | 0      | "second"| []        | {pizza:2} | 0      | (empty)                       | [{type:"pizza"}] | 0                       | {}             | [Block("pizza" Range(second)), Block("pizza" Range(second))] |
      | 2          | "first" | []        | {pizza:2} | 0      | "second"| []        | {}        | 0      | (empty)                       | [{type:"pizza"}] | 0                       | {}             | [Block("pizza" Range(first)), Block("pizza" Range(first))] |
      | 2          | "first" | []        | {}        | 0      | "second"| []        | {}        | 0      | (empty)                       | [{type:"pizza"}] | 0                       | {}             | (empty)         |

  Scenario Outline: Merged Body PartialContent retrieval
    Given <num_bodies> HCL bodies are defined as:
      | BodyIndex | Name   | HasAttributes | HasBlocks        | DiagCount |
      | 1         | <Name1>| <Attrs1>      | <Blocks1>        | <Diags1>  |
      | 2         | <Name2>| <Attrs2>      | <Blocks2>        | <Diags2>  | # If num_bodies is 2
    And these bodies are merged using `MergeBodies`.
    And a BodySchema is defined with:
      | type              | schema_details          |
      | attributes        | <attrs_schema>          |
      | blocks            | <blocks_schema>         |
    When the `PartialContent` method is called on the merged body with the schema
    Then the number of diagnostics should be <expected_total_diag_count>
    And the returned BodyContent should have:
      | type              | content_details         |
      | attributes        | <expected_attrs_content>|
      | blocks            | <expected_blocks_content>|
    And the returned 'remaining' Body should effectively represent:
      | BodyIndex | Name   | HasAttributes      | HasBlocks           |
      | 1         | <Name1>| <RemainAttrs1>     | <RemainBlocks1>     |
      | 2         | <Name2>| <RemainAttrs2>     | <RemainBlocks2>     | # If num_bodies is 2

    Examples:
      | num_bodies | Name1 | Attrs1 | Blocks1 | Diags1 | Name2 | Attrs2 | Blocks2 | Diags2 | attrs_schema | blocks_schema | expected_total_diag_count | expected_attrs_content | expected_blocks_content | RemainAttrs1 | RemainBlocks1 | RemainAttrs2 | RemainBlocks2 |
      | 0          |       |        |         |        |       |        |         |        | (empty)      | (empty)       | 0                         | {}                     | (empty)                 |              |               |              |               |
      | 1          | "first" | ["name","age"] | {} | 0 |       |        |         |        | [{name:"name"}] | (empty)    | 0                       | {name:Attr("name" Range(first))} | (empty)           | ["age"]      | {}            |              |               |
      | 2          | "first" | ["name","age"] | {} | 0 | "second" | ["name","pizza"] | {} | 0 | [{name:"name"}] | (empty)    | 1                       | {name:Attr("name" Range(first))} | (empty)           | ["age"]      | {}            | ["pizza"]    | {}            | # Duplicate "name" causes diag
      | 2          | "first" | ["name","age"] | {} | 0 | "second" | ["pizza","soda"] | {} | 0 | [{name:"name"},{name:"soda"}] | (empty) | 0          | {name:Attr("name" Range(first)),soda:Attr("soda" Range(second))} | (empty) | ["age"] | {} | ["pizza"] | {}            |
      | 2          | "first" | [] | {pizza:1} | 0 | "second" | [] | {pizza:1,soda:2} | 0 | (empty) | [{type:"pizza"}] | 0         | {}                     | [Block("pizza" Range(first)),Block("pizza" Range(second))] | [] | {} | [] | {soda:2}      |

    # Notes for tables:
    # - (empty) for schema/content means an empty list/map or no schema defined.
    # - Attr("name" Range(origin)) means an hcl.Attribute named "name" whose NameRange.Filename is "origin".
    # - Block("type" Range(origin)) means an hcl.Block of "type" whose DefRange.Filename is "origin".
    # - {} for attributes/blocks means an empty map/list.
    # - String arrays like ["name"] denote attribute names or remaining attribute names.
    # - Maps like {pizza:1} denote block types and their counts or remaining block types and counts.
