Feature: subscription management
  As a user of the Tarot API
  I want to manage my subscription
  So that I can access premium features and increased quotas

  Scenario: Subscribe to basic plan
    Given I am a registered user
    When I subscribe to the "basic" plan with valid payment details
    Then my subscription should be activated
    And I should have access to basic plan features
    And my reading limit should be updated to the basic plan limit

  Scenario: Subscribe to premium plan
    Given I am a registered user
    When I subscribe to the "premium" plan with valid payment details
    Then my subscription should be activated
    And I should have access to premium plan features
    And I should have access to premium LLM models
    And my reading limit should be updated to the premium plan limit

  Scenario: Cancel subscription
    Given I am a user with an active subscription
    When I cancel my subscription
    Then my subscription should be marked for cancellation
    And I should retain access until the end of the billing period
    And I should be notified of the cancellation date

  Scenario: Upgrade subscription
    Given I am a user with a "basic" subscription
    When I upgrade to the "premium" plan
    Then my subscription should be updated
    And I should be charged the prorated difference
    And I should immediately have access to premium features

  Scenario: Downgrade subscription
    Given I am a user with a "premium" subscription
    When I downgrade to the "basic" plan
    Then my subscription should be updated at the end of the billing period
    And I should be notified of when the change takes effect

  Scenario: Reactivate cancelled subscription
    Given I am a user with a cancelled subscription
    When I reactivate my subscription
    Then my subscription should be active again
    And I should have immediate access to my previous plan's features

  Scenario: View subscription details
    Given I am a user with an active subscription
    When I request my subscription details
    Then I should see my current plan
    And I should see my billing period
    And I should see my usage statistics

  Scenario: Failed payment handling
    Given I am a user with an active subscription
    When my subscription payment fails
    Then I should be notified of the failed payment
    And I should have a grace period to update payment details
    And my access should be maintained during the grace period
