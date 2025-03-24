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

  Scenario: check detailed health status as admin
    Given i am authenticated as an admin
    When i request the detailed health status
    Then i should receive a success response
    And the response should contain overall system status
    And the response should contain component statuses
    And the response should include database pool statistics
    And the response should include redis pool statistics

  Scenario: check database health status as admin
    Given i am authenticated as an admin
    When i request the database health status
    Then i should receive a success response
    And the response should contain database status
    And the response should include database version information
    And the response should include database pool statistics

  Scenario: non-admin user attempts to access detailed health
    Given i am authenticated as a regular user
    When i try to access the detailed health status
    Then i should receive an error response with status 403

  Scenario: non-admin user attempts to access database health
    Given i am authenticated as a regular user
    When i try to access the database health status
    Then i should receive an error response with status 403

  Scenario: unauthenticated user attempts to access health status
    When i try to access the detailed health status without authentication
    Then i should receive an error response with status 401

  Scenario: system status is degraded
    Given i am authenticated as an admin
    And the system is experiencing database connection issues
    When i request the detailed health status
    Then i should receive a response with status 503
    And the response should indicate degraded system status
    And the response should identify the problematic component

  Scenario: database pool is near capacity
    Given i am authenticated as an admin
    And the database connection pool is heavily utilized
    When i request the database health status
    Then i should receive a success response
    And the response should indicate a warning for the database pool
    And the response should show high usage percentage
