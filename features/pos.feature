# Covers tests in ./pos_test.go
# Specifically, TestRangeOver, TestPosOverlap, and TestRangePartitionAround

Feature: HCL Position and Range Operations
  This feature describes operations on HCL source code positions and ranges,
  such as finding encompassing ranges, overlaps, and partitioning ranges.

  Background:
    Given HCL positions are defined by byte offset, line number, and column number.
    And HCL ranges are defined by a start and end position.

  Scenario Outline: Calculate Encompassing Range (RangeOver)
    Given range A from <a_start_byte> to <a_end_byte>
    And range B from <b_start_byte> to <b_end_byte>
    When RangeOver(A, B) is calculated
    Then the resulting range should be from <expected_start_byte> to <expected_end_byte>

    Examples:
      | a_start_byte | a_end_byte | b_start_byte | b_end_byte | expected_start_byte | expected_end_byte |
      | 2            | 4          | 1            | 5          | 1                   | 5                 | # A:   ## , B:  #### , Want:  ####
      | 0            | 4          | 1            | 5          | 0                   | 5                 | # A: #### , B:  #### , Want: #####
      | 2            | 6          | 1            | 5          | 1                   | 6                 | # A:   ####, B:  #### , Want:  #####
      | 1            | 5          | 2            | 4          | 1                   | 5                 | # A:  #### , B:   ##  , Want:  ####
      | 1            | 4          | 1            | 5          | 1                   | 5                 | # A:  ###  , B:  #### , Want:  ####
      | 2            | 5          | 1            | 5          | 1                   | 5                 | # A:   ### , B:  #### , Want:  ####
      | 2            | 5          | 2            | 5          | 2                   | 5                 | # A:  #### , B:  #### , Want:  #### (exact match)
      | 0            | 2          | 4            | 6          | 0                   | 6                 | # A: ##    , B:     ##, Want: ###### (no overlap)
      | 4            | 6          | 0            | 2          | 0                   | 6                 | # A:     ##, B: ##    , Want: ###### (no overlap, B first)

  Scenario Outline: Calculate Overlapping Range (Overlap)
    Given range A from <a_start_byte> to <a_end_byte>
    And range B from <b_start_byte> to <b_end_byte>
    When A.Overlap(B) is calculated
    Then the resulting range should be from <expected_start_byte> to <expected_end_byte>

    Examples:
      | a_start_byte | a_end_byte | b_start_byte | b_end_byte | expected_start_byte | expected_end_byte |
      | 2            | 4          | 1            | 5          | 2                   | 4                 | # A:   ## , B:  #### , Want:   ##
      | 0            | 4          | 1            | 5          | 1                   | 4                 | # A: #### , B:  #### , Want:  ###
      | 2            | 6          | 1            | 5          | 2                   | 5                 | # A:   ####, B:  #### , Want:   ###
      | 1            | 5          | 2            | 4          | 2                   | 4                 | # A:  #### , B:   ##  , Want:   ##
      | 1            | 4          | 1            | 5          | 1                   | 4                 | # A:  ###  , B:  #### , Want:  ###
      | 2            | 5          | 1            | 5          | 2                   | 5                 | # A:   ### , B:  #### , Want:   ###
      | 2            | 5          | 2            | 5          | 2                   | 5                 | # A:  #### , B:  #### , Want:  #### (exact match)
      | 0            | 2          | 4            | 6          | 0                   | 0                 | # A: ##    , B:     ##, Want: (empty at start of A)
      | 4            | 6          | 0            | 2          | 4                   | 4                 | # A:     ##, B: ##    , Want: (empty at start of A)

  Scenario Outline: Partition Outer Range Around Inner Range
    Given outer range from <outer_start_byte> to <outer_end_byte>
    And inner range from <inner_start_byte> to <inner_end_byte>
    When the outer range is partitioned around the inner range
    Then the 'before' part should be from <before_start_byte> to <before_end_byte>
    And the 'overlap' part should be from <overlap_start_byte> to <overlap_end_byte>
    And the 'after' part should be from <after_start_byte> to <after_end_byte>

    Examples:
      | outer_start_byte | outer_end_byte | inner_start_byte | inner_end_byte | before_start_byte | before_end_byte | overlap_start_byte | overlap_end_byte | after_start_byte | after_end_byte |
      | 2                | 4              | 1                | 5              | 2                 | 2               | 2                  | 4                | 4                | 4              | # Outer:   ##, Inner:  ####
      | 0                | 4              | 1                | 5              | 0                 | 1               | 1                  | 4                | 4                | 4              | # Outer: ####, Inner:  ####
      | 2                | 5              | 1                | 5              | 2                 | 2               | 2                  | 5                | 5                | 5              | # Outer:   ###, Inner:  ####
      | 1                | 5              | 2                | 4              | 1                 | 2               | 2                  | 4                | 4                | 5              | # Outer:  ####, Inner:   ##
