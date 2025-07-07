# Covers utility functions on the hcl.Blocks type in ./structure.go

Feature: HCL Blocks Collection Operations
  This feature tests utility methods available on a collection of HCL Blocks,
  such as filtering by type or grouping by type.

  Background:
    Given a collection of HCL Blocks.

  Scenario: Filtering Blocks by Type using OfType
    Given a list of blocks with the following types and labels:
      | Type    | Labels   |
      | "typeA" | ["l1"]   |
      | "typeB" | ["l2"]   |
      | "typeA" | ["l3"]   |
      | "typeC" | []       |
    When `OfType("typeA")` is called on this list of blocks
    Then the resulting list of blocks should contain 2 block(s)
    And all blocks in the resulting list should have type "typeA"
    And their labels should be ["l1"] and ["l3"] respectively (order preserved)

  Scenario: Filtering Blocks by a Type that does not exist
    Given a list of blocks with the following types and labels:
      | Type    | Labels |
      | "typeA" | ["l1"] |
      | "typeB" | ["l2"] |
    When `OfType("typeX")` is called on this list of blocks
    Then the resulting list of blocks should be empty

  Scenario: Filtering Blocks from an empty list
    Given an empty list of blocks
    When `OfType("typeA")` is called on this list of blocks
    Then the resulting list of blocks should be empty

  Scenario: Grouping Blocks by Type using ByType
    Given a list of blocks with the following types and labels:
      | Type    | Labels   |
      | "typeA" | ["l1a"]  |
      | "typeB" | ["l1b"]  |
      | "typeA" | ["l2a"]  |
      | "typeC" | []       |
      | "typeB" | ["l2b"]  |
    When `ByType()` is called on this list of blocks
    Then the resulting map of blocks should have 3 keys: "typeA", "typeB", "typeC"
    And the list of blocks for key "typeA" should contain 2 block(s) with labels ["l1a"] and ["l2a"] (order preserved from original list)
    And the list of blocks for key "typeB" should contain 2 block(s) with labels ["l1b"] and ["l2b"] (order preserved from original list)
    And the list of blocks for key "typeC" should contain 1 block(s) with no labels

  Scenario: Grouping Blocks by Type from an empty list
    Given an empty list of blocks
    When `ByType()` is called on this list of blocks
    Then the resulting map of blocks should be empty

  Scenario: Grouping Blocks by Type with only unique types
    Given a list of blocks with the following types and labels:
      | Type    | Labels |
      | "typeA" | ["l1"] |
      | "typeB" | ["l2"] |
      | "typeC" | ["l3"] |
    When `ByType()` is called on this list of blocks
    Then the resulting map of blocks should have 3 keys: "typeA", "typeB", "typeC"
    And the list of blocks for key "typeA" should contain 1 block(s)
    And the list of blocks for key "typeB" should contain 1 block(s)
    And the list of blocks for key "typeC" should contain 1 block(s)
