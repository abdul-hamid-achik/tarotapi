Feature: oauth api
  as an api client
  i want to implement the oauth authorization flow
  so that i can securely authenticate users and access their data

  Scenario: initiate oauth authorization flow
    Given the api is available
    And there is a registered api client with id "test_client"
    When i request authorization with valid parameters
      | client_id   | redirect_uri                  | scope      | response_type | state  |
      | test_client | https://client.example.com/cb | read,write | code          | xyz123 |
    Then i should receive a success response
    And the response should contain a redirect link if not authenticated

  Scenario: initiate oauth authorization flow with authenticated user
    Given i am authenticated
    And there is a registered api client with id "test_client"
    When i request authorization with valid parameters
      | client_id   | redirect_uri                  | scope      | response_type | state  |
      | test_client | https://client.example.com/cb | read,write | code          | xyz123 |
    Then i should receive a success response
    And the response should contain an authorization code
    And the response should include the state parameter

  Scenario: request authorization with invalid parameters
    Given the api is available
    And there is a registered api client with id "test_client"
    When i request authorization with invalid parameters
      | client_id   | scope      | response_type |
      | test_client | read,write | code          |
    Then i should receive an error response with status 400
    And the response should contain an error "invalid_request"

  Scenario: request authorization with invalid client
    Given the api is available
    When i request authorization with an invalid client id
      | client_id      | redirect_uri                  | scope      | response_type | state  |
      | invalid_client | https://client.example.com/cb | read,write | code          | xyz123 |
    Then i should receive an error response with status 401
    And the response should contain an error "invalid_client"

  Scenario: exchange authorization code for token
    Given i have a valid authorization code "valid_auth_code" for client "test_client"
    When i request an access token with the authorization code
      | grant_type         | code            | client_id   | client_secret      |
      | authorization_code | valid_auth_code | test_client | test_client_secret |
    Then i should receive a success response
    And the response should contain an access token
    And the response should contain a refresh token
    And the response should include token expiration

  Scenario: exchange expired authorization code
    Given i have an expired authorization code "expired_auth_code" for client "test_client"
    When i request an access token with the authorization code
      | grant_type         | code              | client_id   | client_secret      |
      | authorization_code | expired_auth_code | test_client | test_client_secret |
    Then i should receive an error response with status 400
    And the response should contain an error "invalid_grant"

  Scenario: exchange token with invalid grant type
    Given i have a valid authorization code "valid_auth_code" for client "test_client"
    When i request an access token with invalid grant type
      | grant_type | code            | client_id   | client_secret      |
      | password   | valid_auth_code | test_client | test_client_secret |
    Then i should receive an error response with status 400
    And the response should contain an error "unsupported_grant_type"
