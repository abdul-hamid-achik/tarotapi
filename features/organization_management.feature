Feature: organization management
  As an organization administrator
  I want to manage my organization and its members
  So that I can control access and monitor usage

  Scenario: Create new organization
    Given I am a registered user
    When I create a new organization with valid details
    Then the organization should be created
    And I should be assigned as an admin
    And default quotas should be set based on the plan

  Scenario: Add member to organization
    Given I am an organization admin
    When I invite a user to the organization
    Then an invitation should be sent to the user
    And a membership record should be created with "invited" status
    And the member count should be tracked

  Scenario: Accept organization invitation
    Given I am an invited user
    When I accept the organization invitation
    Then my membership status should change to "active"
    And I should have access to organization resources

  Scenario: Organization plan features
    Given I am an organization admin
    When I view the organization features
    Then I should see the feature limits for my plan
    And I should see the current usage against those limits

  Scenario: Organization member roles
    Given I am an organization admin
    When I change a member's role
    Then the member's permissions should be updated
    And the change should be logged

  Scenario: Organization quota management
    Given I am an organization admin
    When I view the organization quotas
    Then I should see daily reading limits
    And I should see monthly API call limits
    And I should see concurrent session limits

  Scenario: Organization usage analytics
    Given I am an organization admin
    When I request usage analytics
    Then I should see API call statistics
    And I should see unique user counts
    And I should see error rates
    And I should see response times

  Scenario: Organization member suspension
    Given I am an organization admin
    When I suspend a member's access
    Then their membership status should change to "suspended"
    And they should lose access to organization resources

  Scenario: Organization plan upgrade
    Given I am an organization admin
    When I upgrade the organization plan
    Then the feature limits should be updated
    And the quota limits should be increased
    And existing members should get access to new features

  Scenario: list my organizations
    Given i am authenticated
    When i request my organizations
    Then i should receive a success response
    And the response should contain a list of organizations

  Scenario: view organization details
    Given i am authenticated
    And i am a member of an organization
    When i request organization details
    Then i should receive a success response
    And the response should contain organization information

  Scenario: create a new organization
    Given i am authenticated
    When i create an organization with valid data
      | name     | billing_email       |
      | Test Org | billing@example.com |
    Then i should receive a success response with status 201
    And the response should contain the organization details
    And i should be an admin member of the organization

  Scenario: create organization with invalid data
    Given i am authenticated
    When i create an organization with invalid data
      | name | billing_email |
      |      | invalid-email |
    Then i should receive an error response with status 422
    And the response should contain validation errors

  Scenario: update organization
    Given i am authenticated
    And i am an admin of an organization
    When i update the organization with new data
      | name        | billing_email           |
      | Updated Org | new-billing@example.com |
    Then i should receive a success response
    And the response should contain the updated information

  Scenario: non-admin attempting to update organization
    Given i am authenticated
    And i am a regular member of an organization
    When i try to update the organization
    Then i should receive an error response with status 403

  Scenario: delete organization
    Given i am authenticated
    And i am an admin of an organization
    When i delete the organization
    Then i should receive a success response with status 204

  Scenario: add member to organization
    Given i am authenticated
    And i am an admin of an organization
    When i add a new member to the organization
      | email              | role   | name       |
      | member@example.com | member | New Member |
    Then i should receive a success response with status 201
    And the response should contain the membership details

  Scenario: remove member from organization
    Given i am authenticated
    And i am an admin of an organization with members
    When i remove a member from the organization
    Then i should receive a success response with status 204

  Scenario: view organization usage
    Given i am authenticated
    And i am a member of an organization
    When i request usage data for the organization
    Then i should receive a success response
    And the response should contain usage metrics

  Scenario: filter usage by date range
    Given i am authenticated
    And i am a member of an organization
    When i request usage data with date filters
      | start_date | end_date   | granularity |
      | 2023-01-01 | 2023-01-31 | daily       |
    Then i should receive a success response
    And the response should contain filtered usage data

  Scenario: view organization analytics
    Given i am authenticated
    And i am an admin of an organization
    When i request analytics data for the organization
    Then i should receive a success response
    And the response should contain analytics metrics
