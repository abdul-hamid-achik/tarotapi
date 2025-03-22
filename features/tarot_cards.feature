Feature: tarot cards api
  as an api client
  i want to manage and query tarot cards
  so that i can access card information for readings

  Scenario: list all tarot cards
    Given the api is available
    When i request all tarot cards
    Then i should receive a list of cards
    And each card should have basic attributes

  Scenario: get card details
    Given there is an existing tarot card
    When i request the card details
    Then i should receive complete card information

  Scenario: filter cards by suit
    Given there are cards of different suits
    When i filter cards by a specific suit
    Then i should only receive cards of that suit

  Scenario: search cards by keyword
    Given there are cards with different meanings
    When i search for cards with a specific keyword
    Then i should receive cards matching that keyword

  Scenario: get reversed meaning
    Given there is a card with reversed meaning
    When i request the card's reversed interpretation
    Then i should receive the reversed meaning

  Scenario: list cards by category
    Given there are cards of different categories
    When i filter cards by category
    Then i should only receive cards of that category 