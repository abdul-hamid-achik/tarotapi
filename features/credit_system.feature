Feature: credit system
  As a user of the Tarot API
  I want to purchase and use reading credits
  So that I can continue using the service when I exceed my quota

  Scenario: Purchase credit package
    Given I am a registered user
    When I purchase a package of 10 reading credits
    Then my credit balance should increase by 10
    And I should receive a purchase confirmation
    And the credits should never expire

  Scenario: Use credits for readings
    Given I am a registered user with credits
    When I have exceeded my monthly quota
    And I request a reading using credits
    Then one credit should be deducted
    And I should receive my reading
    And I should see my updated credit balance

  Scenario: Credit cost for complex spreads
    Given I am a registered user with credits
    When I request a complex spread reading
    Then the appropriate number of credits should be deducted
    And I should be informed of the cost before confirming
    And I should receive my reading

  Scenario: Credit balance notification
    Given I am a registered user with credits
    When my credit balance falls below 5
    Then I should receive a low balance notification
    And I should be offered options to purchase more credits

  Scenario: Volume discount on credits
    Given I am a registered user
    When I view the credit packages
    Then I should see volume discounts for larger packages
    And I should see the cost per credit for each package

  Scenario: Credit purchase history
    Given I am a registered user who has purchased credits
    When I view my credit history
    Then I should see all my credit purchases
    And I should see my credit usage
    And I should see my current balance

  Scenario: Credit refund
    Given I am a registered user with credits
    When a reading fails to complete
    Then my credit should be refunded
    And I should receive a notification about the refund

  Scenario: Credit sharing restrictions
    Given I am a registered user with credits
    When I attempt to transfer credits to another user
    Then I should receive an error message
    And my credits should remain unchanged

  Scenario: Credit usage with subscription
    Given I am a user with an active subscription
    When I have remaining subscription quota
    Then I should not be prompted to use credits
    And my credits should be preserved for future use
