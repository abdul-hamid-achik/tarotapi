Feature: seance api
  as an api client
  i want to create and validate seance tokens
  so that i can authenticate for real-time communications

  Scenario: create a new seance token
    Given the api is available
    When i request a new seance token with client id "test-client-123"
    Then i should receive a success response with status 201
    And the response should contain a seance token
    And the response should include token expiration time

  Scenario: create a seance token without client id
    Given the api is available
    When i request a new seance token without a client id
    Then i should receive an error response with status 422
    And the response should contain an error message

  Scenario: validate a valid seance token
    Given i have a valid seance token
    When i validate the seance token
    Then i should receive a success response
    And the response should indicate the token is valid
    And the response should include the client id

  Scenario: validate an expired seance token
    Given i have an expired seance token
    When i validate the seance token
    Then i should receive an error response with status 401
    And the response should indicate the token is invalid
    And the response should contain an error about expiration

  Scenario: validate a tampered seance token
    Given i have a tampered seance token
    When i validate the seance token
    Then i should receive an error response with status 401
    And the response should indicate the token is invalid
    And the response should contain an error about token validity

  Scenario: validate without providing a token
    Given the api is available
    When i validate without providing a token
    Then i should receive an error response with status 401
    And the response should indicate the token is invalid
    And the response should contain an error message "missing token"
