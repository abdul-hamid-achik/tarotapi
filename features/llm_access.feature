Feature: LLM model access
  As a user of the Tarot API
  I want to access different LLM models based on my subscription
  So that I can get varying levels of reading interpretations

  Scenario: Anonymous user LLM access
    Given I am an anonymous user
    When I request a tarot reading
    Then the reading should use the Ollama model
    And I should receive a basic interpretation

  Scenario: Free registered user LLM access
    Given I am a registered user without a subscription
    When I request a tarot reading
    Then the reading should use the Ollama model
    And I should receive a basic interpretation
    And I should see options to upgrade for premium models

  Scenario: Basic subscriber LLM access
    Given I am a user with a "basic" subscription
    When I request a tarot reading
    Then I should be able to choose between Ollama and basic cloud models
    And I should receive a standard interpretation
    And I should see my remaining LLM quota for the month

  Scenario: Premium subscriber LLM access
    Given I am a user with a "premium" subscription
    When I request a tarot reading
    Then I should have access to premium LLM models
    And I should receive an advanced interpretation
    And I should not be limited by LLM quotas

  Scenario: LLM model switching
    Given I am a user with a "basic" subscription
    When I switch between available LLM models
    Then each reading should use the selected model
    And my LLM quota should be updated accordingly

  Scenario: LLM quota tracking
    Given I am a user with a "basic" subscription
    When I make multiple reading requests
    Then my LLM usage should be tracked
    And I should be notified when approaching my quota limit

  Scenario: Premium model access restriction
    Given I am a registered user without a subscription
    When I attempt to use a premium LLM model
    Then I should receive an error message
    And I should be offered options to upgrade my subscription

  Scenario: Model fallback behavior
    Given I am a user with a "basic" subscription
    When the selected LLM model is temporarily unavailable
    Then the system should fallback to an alternative model
    And I should be notified of the temporary change

  Scenario: Custom spread complexity affecting LLM usage
    Given I am a user with a "premium" subscription
    When I request a complex spread reading
    Then the LLM should handle the increased complexity
    And I should receive detailed interpretations for all cards
