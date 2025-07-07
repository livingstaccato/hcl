# Covers tests in ./json/didyoumean_test.go
# Specifically, TestKeywordSuggestion

Feature: JSON Keyword Suggestion (Did You Mean)
  This feature tests the `keywordSuggestion` function, which attempts to suggest
  a correct JSON keyword (true, false, null) if a given input string seems
  like a misspelling of one of these keywords.

  Scenario Outline: Suggesting JSON keywords based on input string
    Given the input string "<input_string>"
    When the `keywordSuggestion` function is called
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
      | flue         | false               | # Interesting case, might be close to "true" too

      # Suggestions for "null"
      | input_string | expected_suggestion |
      | nil          | null                |
      | nul          | null                |
      | unll         | null                |
      | nll          | null                |
