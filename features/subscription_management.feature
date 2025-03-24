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

  Scenario: list available subscriptions
    Given i am authenticated
    When i request my subscriptions
    Then i should receive a success response
    And the response should contain a list of my subscriptions

  Scenario: view subscription details
    Given i am authenticated
    And i have an active subscription
    When i request subscription details
    Then i should receive a success response
    And the response should contain subscription information
    And the response should include the subscription status
    And the response should include the current period end date

  Scenario: create a new subscription
    Given i am authenticated
    And i have a payment method
    When i subscribe to a plan with name "premium"
    Then i should receive a success response with status 201
    And the response should contain subscription details
    And the response should contain client secret for payment confirmation

  Scenario: create subscription with invalid plan
    Given i am authenticated
    When i subscribe to a plan with name "non_existent_plan"
    Then i should receive an error response with status 422
    And the response should contain an error message

  Scenario: cancel subscription
    Given i am authenticated
    And i have an active subscription
    When i cancel my subscription
    Then i should receive a success response
    And the response should indicate the subscription is canceled
    And the response should include the end date

  Scenario: change subscription plan
    Given i am authenticated
    And i have an active subscription with plan "basic"
    When i change my plan to "premium"
    Then i should receive a success response
    And the response should indicate the new plan is "premium"

  Scenario: reactivate canceled subscription
    Given i am authenticated
    And i have a canceled subscription that has not expired
    When i reactivate my subscription
    Then i should receive a success response
    And the response should indicate the subscription is active

  Scenario: view payment methods
    Given i am authenticated
    When i request my payment methods
    Then i should receive a success response
    And the response should contain a list of my payment methods

  Scenario: add new payment method
    Given i am authenticated
    When i add a new payment method with id "pm_123456789"
    Then i should receive a success response with status 201
    And the response should contain the payment method details

  Scenario: set payment method as default
    Given i am authenticated
    And i have a non-default payment method
    When i add a new payment method with id "pm_default_test" as default
    Then i should receive a success response with status 201
    And the response should indicate the payment method is default

  Scenario: remove payment method
    Given i am authenticated
    And i have multiple payment methods
    When i remove a non-default payment method
    Then i should receive a success response
    And the payment method should be removed

  Scenario: attempt to remove default payment method
    Given i am authenticated
    And i have a default payment method
    When i try to remove the default payment method
    Then i should receive an error response with status 422
    And the response should contain an error about default payment method
