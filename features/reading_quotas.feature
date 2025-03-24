Feature: reading quota management
  As a user of the Tarot API
  I want to understand and manage my reading quotas
  So that I can plan my usage accordingly

  Scenario: Anonymous user quota
    Given I am an anonymous user
    When I request a tarot reading
    Then I should be informed of my daily limit of 3 readings
    And I should see my remaining readings for the day

  Scenario: Free registered user quota
    Given I am a registered user without a subscription
    When I request a tarot reading
    Then I should be informed of my monthly limit
    And I should see my remaining readings for the month

  Scenario: Basic subscriber quota
    Given I am a user with a "basic" subscription
    When I request a tarot reading
    Then I should be informed of my higher monthly limit
    And I should see my remaining readings for the month

  Scenario: Premium subscriber unlimited readings
    Given I am a user with a "premium" subscription
    When I request multiple tarot readings
    Then I should not be limited by a quota
    And I should still see my usage statistics

  Scenario: Quota reset for free user
    Given I am a registered user without a subscription
    And I have used all my monthly readings
    When the monthly reset occurs
    Then my quota should be reset to the default limit
    And I should be able to request readings again

  Scenario: Approaching quota limit
    Given I am a registered user without a subscription
    When I have used 80% of my monthly quota
    Then I should receive a notification about my remaining quota
    And I should be offered options to upgrade my plan

  Scenario: Exceeding quota limit
    Given I am a registered user without a subscription
    When I attempt to exceed my monthly quota
    Then I should receive an error message
    And I should be offered options to purchase credits or upgrade
    And my request should not be processed

  Scenario: IP-based quota for anonymous users
    Given I am an anonymous user
    When I make multiple requests from the same IP
    Then the daily limit should be enforced per IP address
    And I should receive appropriate quota information

  Scenario: Quota tracking across different spread types
    Given I am a registered user
    When I request readings with different spread configurations
    Then each reading should count towards my quota
    And complex spreads should count the same as simple ones
