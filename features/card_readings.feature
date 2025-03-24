Feature: card readings api
  as an api client
  i want to create and manage card readings
  so that i can provide tarot interpretations

  Scenario: create a new card reading
    Given the api is available
    And there is an existing card with id 1
    And there is an existing spread with id 1
    When i create a new card reading
      | card_id | position | is_reversed | question          | notes          |
      |       1 |        1 | false       | Will I find love? | First position |
    Then i should receive a success response with status 200
    And the response should contain card reading details

  Scenario: create a card reading with invalid data
    Given the api is available
    When i create a new card reading with invalid data
      | card_id | position | is_reversed |
      |     999 |        1 | false       |
    Then i should receive an error response with status 422
    And the response should contain validation errors

  Scenario: list card readings for a user
    Given i am authenticated
    And i have existing card readings
    When i request my card readings
    Then i should receive a success response
    And the response should contain a list of card readings

  Scenario: view card reading details
    Given i am authenticated
    And i have an existing card reading
    When i request the card reading details
    Then i should receive a success response
    And the response should contain detailed card reading information

  Scenario: get interpretation for multiple readings
    Given i am authenticated
    And i have multiple card readings for a spread
    When i request an interpretation for those readings
    Then i should receive a success response
    And the response should contain an interpretation

  Scenario: get interpretation for non-existent readings
    Given i am authenticated
    When i request an interpretation for non-existent readings
    Then i should receive an error response with status 404
    And the response should indicate no readings found

  Scenario: analyze card combination
    Given i am authenticated
    And there are cards with ids 1 and 2
    When i request an analysis for card combination 1 and 2
    Then i should receive a success response
    And the response should contain a combination analysis

  Scenario: analyze combination with invalid card
    Given i am authenticated
    And there is a card with id 1
    When i request an analysis for card combination 1 and 999
    Then i should receive an error response with status 404
    And the response should indicate cards not found
