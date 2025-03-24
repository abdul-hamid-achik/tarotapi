Feature: health monitoring
  As a system operator
  I want to monitor system health
  So that I can ensure service reliability

  Scenario: Basic health check
    Given the system is running
    When I request the public health endpoint
    Then I should receive a 200 status
    And basic system status should be returned

  Scenario: Detailed health check
    Given I am authenticated as an admin
    When I request the detailed health endpoint
    Then I should see:
      | database_status    |
      | redis_status       |
      | llm_service_status |
      | queue_status       |

  Scenario: Database health check
    Given I am authenticated as an admin
    When I request the database health endpoint
    Then I should see:
      | connection_pool_status |
      | replication_lag        |
      | query_performance      |
      | table_statistics       |

  Scenario: LLM service health
    Given the system is running
    When I check LLM service health
    Then I should see status for each provider:
      | ollama  |
      | claude  |
      | gpt-4   |
      | gpt-4o  |
      | gpt-4.5 |
    And response times should be within acceptable limits

  Scenario: Queue health monitoring
    Given background jobs are running
    When I check the job queue health
    Then I should see:
      | queue_length     |
      | job_error_rate   |
      | processing_speed |
      | worker_status    |

  Scenario: Rate limit monitoring
    Given the system is processing requests
    When rate limits are approaching thresholds
    Then alerts should be generated
    And administrators should be notified
    And affected services should be identified

  Scenario: System metrics collection
    Given the monitoring system is active
    When system metrics are collected
    Then I should see:
      | cpu_usage       |
      | memory_usage    |
      | disk_space      |
      | network_traffic |

  Scenario: Service dependency check
    Given I am authenticated as an admin
    When I check service dependencies
    Then I should see status for:
      | stripe_integration |
      | email_service      |
      | storage_service    |
      | cache_service      |

  Scenario: Automated health recovery
    Given a non-critical service is failing
    When the health check detects the failure
    Then recovery procedures should be triggered
    And service status should be monitored
    And administrators should be notified of the recovery attempt
