Feature: API Documentation
  As an API consumer
  I want accurate API documentation
  So that I can properly integrate with the API

  Scenario: OpenAPI specification is valid
    When I request the OpenAPI specification
    Then it should be a valid OpenAPI 3.0 document
    And it should include security schemes
    And it should include authentication endpoints

  Scenario: Documentation includes all endpoints
    When I request the OpenAPI specification
    Then it should document all implemented endpoints
    And each endpoint should have proper request/response schemas

  Scenario: Authentication documentation is complete
    When I request the OpenAPI specification
    Then it should document the registration endpoint
    And it should document the login endpoint
    And it should document the token refresh endpoint
    And all authentication endpoints should have example responses

  Scenario: Error responses are documented
    When I request the OpenAPI specification
    Then each endpoint should document error responses
    And error response schemas should be consistent
    And validation error responses should include example error messages

  Scenario: Rate limiting is documented
    When I request the OpenAPI specification
    Then it should include rate limiting headers in responses
    And it should document rate limit quotas
    And it should provide example rate limit responses 