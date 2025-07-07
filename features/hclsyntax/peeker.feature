# Covers tests in ./hclsyntax/peeker_test.go
# Specifically, TestPeeker

Feature: HCL Syntax - Token Peeker
  This feature tests the `peeker` utility, which allows reading tokens from a
  sequence one by one, with the ability to `Peek()` at the next token without
  consuming it. It also tests the peeker's handling of comments and newlines
  based on its configuration.

  Background:
    Given a sequence of HCL tokens:
      | Type         |
      | TokenIdent   |
      | TokenComment |
      | TokenIdent   |
      | TokenComment |
      | TokenIdent   |
      | TokenNewline |
      | TokenIdent   |
      | TokenNewline |
      | TokenIdent   |
      | TokenNewline |
      | TokenEOF     |

  Scenario: Peeking and Reading tokens with comments and newlines included
    Given a new peeker initialized with the token sequence, including comments and newlines
    When tokens are repeatedly Peeked and then Read until TokenEOF is encountered
    Then each Peeked token type should match the subsequently Read token type
    And the sequence of Read token types should be:
      | Type         |
      | TokenIdent   |
      | TokenComment |
      | TokenIdent   |
      | TokenComment |
      | TokenIdent   |
      | TokenNewline |
      | TokenIdent   |
      | TokenNewline |
      | TokenIdent   |
      | TokenNewline |
      | TokenEOF     |

  Scenario: Peeking and Reading tokens with comments and newlines excluded (skipped)
    Given a new peeker initialized with the token sequence, excluding comments and newlines by default
    When tokens are repeatedly Peeked and then Read until TokenEOF is encountered
    Then each Peeked token type should match the subsequently Read token type
    And the sequence of Read token types should be:
      | Type         |
      | TokenIdent   | # First Ident
      | TokenIdent   | # Second Ident (first comment skipped)
      | TokenIdent   | # Third Ident (second comment skipped)
      | TokenNewline | # First Newline (after third ident)
      | TokenIdent   | # Fourth Ident
      | TokenNewline | # Second Newline (after fourth ident)
      | TokenIdent   | # Fifth Ident
      | TokenNewline | # Third Newline (after fifth ident)
      | TokenEOF     |

  Scenario: Dynamically changing newline inclusion behavior with Push/Pop
    Given a new peeker initialized with the token sequence, excluding comments and newlines by default
    And the peeker's newline inclusion is then set to false (PushIncludeNewlines(false))
    When tokens are repeatedly Peeked and then Read:
      | Iteration | ActionAfterRead      |
      | 0         |                      |
      | 1         |                      |
      | 2         |                      |
      | 3         |                      |
      | 4         | PopIncludeNewlines() | # After reading the 5th significant token (which is the 5th Ident)
      | 5         |                      | # Now newlines should be included again (original peeker default was skip)
      | ...       | (until EOF)          |
    Then each Peeked token type should match the subsequently Read token type
    And the sequence of Read token types should be:
      | Type         |
      | TokenIdent   | # 1st Ident
      | TokenIdent   | # 2nd Ident
      | TokenIdent   | # 3rd Ident
      | TokenIdent   | # 4th Ident (Newline after 3rd Ident was skipped due to Push(false))
      | TokenIdent   | # 5th Ident (Newline after 4th Ident was skipped due to Push(false))
      | TokenNewline | # Newline after 5th Ident (PopIncludeNewlines restored default peeker behavior of skipping comments but not newlines here, though the test implies default was to skip newlines too initially. The Go test is specific about the sequence.)
      | TokenEOF     |
    # Note: The Go test for Push/Pop implies the peeker's initial state (before Push) was to skip newlines.
    # The Gherkin here reflects the Go test's expected output sequence.
    # The key is that PopIncludeNewlines restores the state that was active before the corresponding Push.
    # If the peeker was created with `includeNewlines=false`, then popping would restore that.
    # The test case `newPeeker(tokens, false)` means it starts by skipping comments AND newlines.
    # `PushIncludeNewlines(false)` doesn't change the newline skipping if it's already skipping them.
    # However, the expected output implies a change. This suggests the test might be subtle
    # or my interpretation of the Go test's `newPeeker(tokens, false)` + `PushIncludeNewlines(false)` needs refinement.
    # The Go test's expected output for this specific scenario is: Ident, Ident, Ident, Ident, Ident, Newline, EOF.
    # This implies that after Pop, it started including newlines that it was previously skipping.
    # This means the `newPeeker(tokens, false)` makes it skip comments, and the internal stack for newlines starts as 'skip'.
    # `PushIncludeNewlines(false)` pushes another 'skip' onto the stack.
    # `PopIncludeNewlines()` reverts to the initial 'skip' state for newlines from `newPeeker(tokens, false)`.
    # The Go test's specific token stream for this case is [Ident, Ident, Ident, Ident, Ident, Newline, EOF].
    # This means the *default* for the peeker when `includeComments` is false *is* to include newlines, and `PushIncludeNewlines(false)` overrides that.
    # Let's adjust the Gherkin for clarity based on this re-interpretation.

  Scenario: Dynamically changing newline inclusion with Push(false) then Pop
    Given a new peeker initialized with the token sequence, configured to skip comments but INCLUDE newlines by default (implicit from Go test structure)
    And the peeker's newline inclusion is then explicitly set to skip newlines using `PushIncludeNewlines(false)`
    When tokens are repeatedly Peeked and then Read
    And after the 5th non-comment token is read (which is the 5th TokenIdent)
    Then `PopIncludeNewlines()` is called on the peeker
    And reading continues until TokenEOF
    Then each Peeked token type should match the subsequently Read token type
    And the sequence of Read token types should be:
      | Type         |
      | TokenIdent   | # Initial Ident
      | TokenIdent   | # Skips comment, reads next Ident. Newlines initially skipped by Push(false)
      | TokenIdent   |
      | TokenIdent   |
      | TokenIdent   | # 5th Ident read. Newline after it skipped. Now PopIncludeNewlines() is called.
      | TokenNewline | # Newline after 5th Ident is now included because Pop restored default (include newlines).
      | TokenEOF     |
