Feature: user management api
  as an api client
  i want to manage user accounts
  so that i can handle user authentication and profiles

  Scenario: register new user
    When i submit valid registration details
    Then a new user account should be created
    And i should receive an authentication token

  Scenario: login user
    Given there is a registered user
    When i submit valid login credentials
    Then i should receive an authentication token
    And i should receive the user profile

  Scenario: update user profile
    Given i am an authenticated user
    When i update my profile information
    Then my profile should be updated
    And i should see the updated information

  Scenario: change password
    Given i am an authenticated user
    When i submit a valid password change request
    Then my password should be updated
    And i should be able to login with the new password

  Scenario: request password reset
    Given there is a registered user
    When i request a password reset
    Then a password reset token should be generated
    And a reset email should be sent

  Scenario: validate reset token
    Given there is a valid password reset token
    When i submit the reset token
    Then the token should be validated
    And i should be allowed to set a new password

  Scenario: get user reading history
    Given i am an authenticated user
    And i have previous readings
    When i request my reading history
    Then i should receive a list of my past readings 