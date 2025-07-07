# Covers types and functions in ./pos.go
# Based on test cases in ./pos_test.go (TestRangeOver, TestPosOverlap, TestRangePartitionAround)
# and analysis of pos.go for other public APIs.

Feature: HCL Source Position and Range Operations
  This feature describes operations on HCL source code positions (Pos) and ranges (Range),
  including their creation, manipulation (finding encompassing ranges, overlaps, partitions),
  string representation, containment checks, and byte slicing.

  Background:
    Given HCL positions are defined by Filename, Byte offset, Line number, and Column number.
    And HCL ranges are defined by a Start (inclusive) and End (exclusive) position.

  Scenario Outline: Calculate Encompassing Range (RangeOver)
    Given range A from byte <a_start_byte> to <a_end_byte> in file "test.hcl"
    And range B from byte <b_start_byte> to <b_end_byte> in file "test.hcl"
    When `hcl.RangeOver(A, B)` is calculated
    Then the resulting range should be from byte <expected_start_byte> to <expected_end_byte> in file "test.hcl"

    Examples:
      | a_start_byte | a_end_byte | b_start_byte | b_end_byte | expected_start_byte | expected_end_byte |
      | 2            | 4          | 1            | 5          | 1                   | 5                 | # A inside B
      | 0            | 4          | 1            | 5          | 0                   | 5                 | # A overlaps start of B
      | 2            | 6          | 1            | 5          | 1                   | 6                 | # B overlaps start of A
      | 1            | 5          | 2            | 4          | 1                   | 5                 | # B inside A
      | 0            | 2          | 4            | 6          | 0                   | 6                 | # Disjoint, A before B
      | 4            | 6          | 0            | 2          | 0                   | 6                 | # Disjoint, B before A
      | 2            | 5          | 2            | 5          | 2                   | 5                 | # Identical

  Scenario Outline: Calculate Overlapping Range (Range.Overlap)
    Given range A from byte <a_start_byte> to <a_end_byte> in file "test.hcl"
    And range B from byte <b_start_byte> to <b_end_byte> in file "test.hcl"
    When `A.Overlap(B)` is calculated
    Then the resulting overlap range should be from byte <expected_start_byte> to <expected_end_byte> in file "test.hcl"

    Examples:
      | a_start_byte | a_end_byte | b_start_byte | b_end_byte | expected_start_byte | expected_end_byte |
      | 2            | 4          | 1            | 5          | 2                   | 4                 | # A inside B
      | 0            | 4          | 1            | 5          | 1                   | 4                 | # A overlaps start of B
      | 2            | 6          | 1            | 5          | 2                   | 5                 | # B overlaps start of A
      | 1            | 5          | 2            | 4          | 2                   | 4                 | # B inside A
      | 0            | 2          | 4            | 6          | 0                   | 0                 | # Disjoint, A before B (empty overlap at start of A)
      | 4            | 6          | 0            | 2          | 4                   | 4                 | # Disjoint, B before A (empty overlap at start of A)
      | 2            | 5          | 2            | 5          | 2                   | 5                 | # Identical

  Scenario Outline: Partition Outer Range Around Inner Range (Range.PartitionAround)
    Given outer range from byte <outer_sB> to <outer_eB> in file "test.hcl"
    And inner range from byte <inner_sB> to <inner_eB> in file "test.hcl"
    When the outer range is partitioned around the inner range
    Then the 'before' part should be from byte <before_sB> to <before_eB>
    And the 'overlap' part should be from byte <overlap_sB> to <overlap_eB>
    And the 'after' part should be from byte <after_sB> to <after_eB> (all in "test.hcl")

    Examples:
      | outer_sB | outer_eB | inner_sB | inner_eB | before_sB | before_eB | overlap_sB | overlap_eB | after_sB | after_eB |
      | 2        | 4        | 1        | 5        | 2         | 2         | 2          | 4          | 4        | 4        | # Outer inside Inner
      | 0        | 4        | 1        | 5        | 0         | 1         | 1          | 4          | 4        | 4        | # Outer overlaps start of Inner
      | 1        | 5        | 2        | 4        | 1         | 2         | 2          | 4          | 4        | 5        | # Inner inside Outer

  Scenario Outline: Range String Representation (Range.String)
    Given a Range in file "<filename>" from Line <sL>, Col <sC> to Line <eL>, Col <eC>
    When `String()` is called on the range
    Then the result should be "<expected_string>"

    Examples:
      | filename   | sL | sC | eL | eC | expected_string        |
      | "f.hcl"    | 1  | 5  | 1  | 10 | "f.hcl:1,5-10"         | # Single line
      | "f.hcl"    | 1  | 5  | 2  | 3  | "f.hcl:1,5-2,3"        | # Multi-line
      | ""         | 1  | 1  | 1  | 1  | ":1,1-1"               | # Empty filename, single line (empty range)

  Scenario Outline: Checking if a Range is Empty (Range.Empty)
    Given a Range with Start Byte <start_byte> and End Byte <end_byte>
    When `Empty()` is called on the range
    Then the result should be <is_empty_expected>

    Examples:
      | start_byte | end_byte | is_empty_expected |
      | 0          | 0        | true              |
      | 0          | 5        | false             |
      | 5          | 5        | true              |

  Scenario Outline: Checking if Range Contains Position/Offset
    Given a Range in file "test.hcl" from Byte <range_start_b> to <range_end_b> (Line 1, Col <range_start_b>+1 to Col <range_end_b>+1)
    When `ContainsOffset` is called with byte offset <test_b>
    Then the result should be <expected_contains>
    When `ContainsPos` is called with Pos (Line 1, Col <test_b>+1, Byte <test_b>)
    Then the result should be <expected_contains>

    Examples:
      | range_start_b | range_end_b | test_b | expected_contains |
      | 10            | 20          | 15     | true              | # Inside
      | 10            | 20          | 10     | true              | # At start
      | 10            | 20          | 5      | false             | # Before start
      | 10            | 20          | 19     | true              | # Before end (exclusive)
      | 10            | 20          | 20     | false             | # At end (exclusive)
      | 10            | 20          | 25     | false             | # After end

  Scenario Outline: Slicing Bytes from a Range (Range.SliceBytes)
    Given a source byte slice represented by hex "<source_hex>" (e.g., "68656c6c6f" for "hello")
    And a Range with Filename "test.hcl", Start Byte <start_b>, End Byte <end_b>
    When `CanSliceBytes` is called with the source bytes
    Then the result should be <can_slice_expected>
    When `SliceBytes` is called with the source bytes
    Then the resulting byte slice (hex) should be "<expected_slice_hex>"

    Examples:
      | source_hex               | start_b | end_b | can_slice_expected | expected_slice_hex       |
      | "68656c6c6f20776f726c64" | 0       | 5     | true               | "68656c6c6f"             | # "hello world" -> "hello"
      | "68656c6c6f20776f726c64" | 6       | 11    | true               | "776f726c64"             | # "hello world" -> "world"
      | "68656c6c6f"             | 0       | 5     | true               | "68656c6c6f"             | # "hello" -> "hello"
      | "68656c6c6f"             | 0       | 0     | true               | ""                       | # Empty slice from empty range
      | "68656c6c6f"             | 5       | 5     | true               | ""                       |
      | "68656c6c6f"             | -1      | 2     | false              | "6865"                   | # Start out of bounds (corrected to 0)
      | "68656c6c6f"             | 3       | 10    | false              | "c6f"                    | # End out of bounds (corrected to len)
      | "68656c6c6f"             | 3       | 2     | false              | ""                       | # End before start (corrected to empty at start)

  Scenario Outline: Checking if Ranges Overlap (Range.Overlaps)
    Given range A from byte <a_start_byte> to <a_end_byte> in "f.hcl"
    And range B from byte <b_start_byte> to <b_end_byte> in "<b_filename>"
    When `A.Overlaps(B)` is called
    Then the result should be <expected_overlap_bool>

    Examples:
      | a_start_byte | a_end_byte | b_start_byte | b_end_byte | b_filename | expected_overlap_bool |
      | 10           | 20         | 15           | 25         | "f.hcl"    | true                  | # Partial overlap
      | 10           | 20         | 5            | 15         | "f.hcl"    | true                  | # Partial overlap
      | 10           | 20         | 12           | 18         | "f.hcl"    | true                  | # B inside A
      | 10           | 20         | 5            | 25         | "f.hcl"    | true                  | # A inside B
      | 10           | 20         | 20           | 30         | "f.hcl"    | false                 | # Adjacent (B after A, end exclusive)
      | 10           | 20         | 0            | 10         | "f.hcl"    | false                 | # Adjacent (B before A, start inclusive)
      | 10           | 20         | 0            | 5          | "f.hcl"    | false                 | # Disjoint (B before A)
      | 10           | 10         | 5            | 15         | "f.hcl"    | false                 | # A is empty
      | 10           | 20         | 15           | 15         | "f.hcl"    | false                 | # B is empty
      | 10           | 20         | 15           | 25         | "g.hcl"    | false                 | # Different files

  Scenario: Creating a Range Between Two Ranges (hcl.RangeBetween)
    Given range_A in "f.hcl" from L1C1B0 to L1C5B4
    And range_B in "f.hcl" from L2C1B10 to L2C5B14
    When `hcl.RangeBetween(range_A, range_B)` is called
    Then the resulting range should be in "f.hcl" from L1C1B0 to L2C5B14
