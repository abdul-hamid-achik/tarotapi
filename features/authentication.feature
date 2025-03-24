Feature: authentication api
  as an api client
  i want to authenticate and manage credentials
  so that i can access protected resources securely

  Scenario: user registration
    Given the api is available
    When i register with valid credentials
      | email            | password | password_confirmation |
      | test@example.com | password | password              |
    Then i should receive a success response with status 201
    And the response should contain a token
    And the response should contain user information

  Scenario: registration with invalid data
    Given the api is available
    When i register with invalid credentials
      | email         | password | password_confirmation |
      | invalid_email | pass     | different_password    |
    Then i should receive an error response with status 422
    And the response should contain validation errors

  Scenario: user login with valid credentials
    Given there is a registered user with email "user@example.com" and password "password123"
    When i login with email "user@example.com" and password "password123"
    Then i should receive a success response
    And the response should contain a token
    And the response should contain refresh token
    And the response should contain user information

  Scenario: user login with invalid credentials
    Given there is a registered user with email "user@example.com" and password "password123"
    When i login with email "user@example.com" and password "wrong_password"
    Then i should receive an error response with status 401
    And the response should contain an error message "invalid email or password"

  Scenario: refresh token
    Given i have a valid refresh token
    When i request a token refresh
    Then i should receive a success response
    And the response should contain a new token

  Scenario: refresh with invalid token
    When i request a token refresh with an invalid token
    Then i should receive an error response with status 401
    And the response should contain an error message "invalid or expired refresh token"

  Scenario: view user profile
    Given i am authenticated
    When i request my profile
    Then i should receive a success response
    And the response should contain my user information

  Scenario: view profile without authentication
    When i request my profile without authentication
    Then i should receive an error response with status 401

  Scenario: create agent user
    Given i am authenticated as a registered user
    When i create an agent with valid credentials
      | email             | password   | password_confirmation |
      | agent@example.com | agent_pass | agent_pass            |
    Then i should receive a success response with status 201
    And the response should contain agent information
    And the response should contain agent token

  Scenario: create agent without authentication
    When i create an agent without authentication
    Then i should receive an error response with status 401
