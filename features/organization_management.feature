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
