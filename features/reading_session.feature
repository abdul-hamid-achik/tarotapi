Feature: tarot reading session api
  as an api client
  i want to create and manage reading sessions
  so that i can provide tarot readings programmatically

  Scenario: create a new reading session
    Given the api is available
    When i request a new reading session with a spread
    And i provide a question
    Then a new reading session should be created with a session id
    And i should receive the drawn cards

  Scenario: retrieve reading session
    Given there is an existing reading session
    When i request the reading session by id
    Then i should receive the complete reading details

  Scenario: list available spreads
    When i request the available spreads
    Then i should receive a list of spread options
    And each spread should include its positions

  Scenario: create reading session with invalid spread
    Given the api is available
    When i request a new reading session with an invalid spread id
    Then i should receive a not found error

  Scenario: create reading session without question
    Given the api is available
    When i request a new reading session without a question
    Then i should receive a validation error

  Scenario: retrieve non-existent reading session
    When i request a reading session with an invalid id
    Then i should receive a not found error

  Scenario: filter readings by date range
    Given i have multiple reading sessions
    When i request readings between specific dates
    Then i should receive only readings within that range

  Scenario: get reading session statistics
    Given i have multiple reading sessions
    When i request reading session statistics
    Then i should receive aggregated reading data 