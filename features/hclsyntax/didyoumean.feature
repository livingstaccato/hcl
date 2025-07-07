# Covers internal hclsyntax.nameSuggestion function in ./hclsyntax/didyoumean.go
# Based on test cases in ./hclsyntax/didyoumean_test.go (TestNameSuggestion)

Feature: HCL Native Syntax - Name Suggestion (Did You Mean) for Keywords
  This feature tests the internal `nameSuggestion` function within the `hclsyntax`
  package, which attempts to suggest a correct HCL keyword (true, false, null)
  if a given input string appears to be a misspelling of one of these keywords.

  Background:
    Given a list of known HCL keywords: "false", "true", "null"

  Scenario Outline: Suggesting HCL keywords based on input string similarity
    Given the input string "<input_string>"
    When the `hclsyntax.nameSuggestion` function is called with the input string and the known keywords
    Then the suggested keyword should be "<expected_suggestion>"

    Examples:
      # Exact matches
      | input_string | expected_suggestion |
      | true         | true                |
      | false        | false               |
      | null         | null                |

      # No suggestion (input is too different or not a keyword-like structure)
      | input_string | expected_suggestion |
      | bananas      |                     |
      | NaN          |                     | # Not an HCL keyword, though a JSON concept
      | Inf          |                     |
      | Infinity     |                     |
      | void         |                     |
      | undefined    |                     | # Not an HCL keyword

      # Suggestions for "true"
      | input_string | expected_suggestion |
      | ture         | true                |
      | tru          | true                |
      | tre          | true                |
      | treu         | true                |
      | rtue         | true                |

      # Suggestions for "false"
      | input_string | expected_suggestion |
      | flase        | false               |
      | fales        | false               |
      | flse         | false               |
      | fasle        | false               |
      | fasel        | false               |
      | flue         | false               |

      # Suggestions for "null"
      | input_string | expected_suggestion |
      | nil          | null                | # "nil" is often typed for "null"
      | nul          | null                |
      | unll         | null                |
      | nll          | null                |
