# Covers tests in ./hclsyntax/didyoumean_test.go
# Specifically, TestNameSuggestion

Feature: HCL Syntax - Name Suggestion (Did You Mean)
  This feature tests the `nameSuggestion` function, which attempts to suggest
  a correct HCL keyword (true, false, null) if a given input string appears
  to be a misspelling of one of these keywords.

  Background:
    Given a list of known HCL keywords: "false", "true", "null".

  Scenario Outline: Suggesting HCL keywords based on input string
    Given the input string "<input_string>"
    When the `nameSuggestion` function is called with the input string and the known keywords
    Then the suggested keyword should be "<expected_suggestion>"

    Examples:
      # Exact matches
      | input_string | expected_suggestion |
      | true         | true                |
      | false        | false               |
      | null         | null                |

      # No suggestion (input is too different or not a keyword)
      | input_string | expected_suggestion |
      | bananas      |                     |
      | NaN          |                     |
      | Inf          |                     |
      | Infinity     |                     |
      | void         |                     |
      | undefined    |                     |

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
      | nil          | null                |
      | nul          | null                |
      | unll         | null                |
      | nll          | null                |
