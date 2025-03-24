Feature: usage tracking
  As a system administrator
  I want to track API and resource usage
  So that I can monitor system health and user behavior

  Scenario: Track API calls
    Given an API request is made
    When the request completes
    Then the call should be logged with:
      | endpoint        |
      | status          |
      | response_time   |
      | user_id         |
      | organization_id |

  Scenario: Track reading sessions
    Given a user starts a reading session
    When they complete the reading
    Then the session should be logged with:
      | user_id        |
      | spread_type    |
      | duration       |
      | llm_model_used |

  Scenario: Track concurrent sessions
    Given multiple users are accessing the system
    When a new session starts
    Then the concurrent session count should be updated
    And it should be checked against the plan limit
    And excess sessions should be rejected

  Scenario: Usage analytics by time period
    Given I am an administrator
    When I request usage analytics for a date range
    Then I should see:
      | daily_active_users    |
      | total_api_calls       |
      | average_response_time |
      | error_rate            |

  Scenario: Resource usage alerts
    Given usage monitoring is active
    When resource usage exceeds 80% of any limit
    Then an alert should be generated
    And administrators should be notified
    And affected users should be warned

  Scenario: Usage quotas reset
    Given it is the start of a new billing period
    When the quota reset job runs
    Then all user quotas should be reset
    And organization quotas should be reset
    And usage statistics should be archived

  Scenario: Error rate monitoring
    Given the system is processing requests
    When errors occur
    Then they should be logged with:
      | error_type   |
      | stack_trace  |
      | user_context |
    And error rates should be calculated
    And alerts should be triggered if thresholds are exceeded

  Scenario: Performance metrics tracking
    Given the system is handling requests
    When response times are recorded
    Then average response times should be calculated
    And slow endpoints should be identified
    And performance degradation should trigger alerts

  Scenario: Usage report generation
    Given I am an administrator
    When I request a usage report
    Then I should receive a report with:
      | user_activity        |
      | resource_consumption |
      | error_patterns       |
      | performance_metrics  |
