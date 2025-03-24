# Web API Security Best Practices

This document outlines security best practices for the Tarot API.

## Authentication and Authorization

### Authentication

The API uses JWT for authentication:

- All tokens are short-lived (24 hours by default)
- JWT secrets are stored as Docker secrets, not in environment variables
- Implement proper token refresh mechanisms
- Use HTTPS for all API communications
- Store hashed passwords using bcrypt (built into Rails)

### Authorization

Use CanCanCan for role-based authorization:

```ruby
# Example ability.rb setup
class Ability
  include CanCan::Ability

  def initialize(user)
    user ||= User.new # Guest user

    if user.admin?
      can :manage, :all
    else
      can :read, Card
      can :create, Reading
      can :update, Reading, user_id: user.id
      can :destroy, Reading, user_id: user.id
    end
  end
end
```

## Input Validation and Sanitization

- Use Rails' built-in validation in models:

```ruby
class Reading < ApplicationRecord
  validates :title, presence: true
  validates :spread_type, inclusion: { in: Reading::VALID_SPREAD_TYPES }
  # Other validations
end
```

- Sanitize user inputs:

```ruby
# Use strong parameters in controllers
def reading_params
  params.require(:reading).permit(:title, :spread_type, :description)
end
```

- Use `ActiveRecord::Base.sanitize_sql` or prepared statements for custom SQL

## API Rate Limiting

- Implement rate limiting using the `rack-attack` gem:

```ruby
# config/initializers/rack_attack.rb
class Rack::Attack
  throttle('req/ip', limit: 300, period: 5.minutes) do |req|
    req.ip
  end

  throttle('logins/ip', limit: 5, period: 20.seconds) do |req|
    if req.path == '/api/v1/auth/login' && req.post?
      req.ip
    end
  end
end
```

## HTTPS and SSL/TLS

- Force HTTPS in production:

```ruby
# config/environments/production.rb
config.force_ssl = true
```

- Use strong SSL/TLS ciphers and disable old protocols
- Implement HTTP Strict Transport Security (HSTS)

## Secure Headers

- Use the `secure_headers` gem to set security headers:

```ruby
# config/initializers/secure_headers.rb
SecureHeaders::Configuration.default do |config|
  config.x_frame_options = "DENY"
  config.x_content_type_options = "nosniff"
  config.x_xss_protection = "1; mode=block"
  config.x_download_options = "noopen"
  config.x_permitted_cross_domain_policies = "none"
  config.referrer_policy = "strict-origin-when-cross-origin"
  
  # CSP settings
  config.csp = {
    default_src: %w('self'),
    script_src: %w('self'),
    style_src: %w('self'),
    img_src: %w('self' data:),
    connect_src: %w('self'),
    font_src: %w('self'),
    object_src: %w('none'),
    frame_ancestors: %w('none'),
    form_action: %w('self'),
    base_uri: %w('self')
  }
end
```

## CORS Configuration

- Restrict CORS to known domains only:

```ruby
# config/initializers/cors.rb
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins ENV['CORS_ORIGINS'].split(',')
    resource '/api/*',
      headers: :any,
      methods: [:get, :post, :patch, :put, :delete, :options],
      credentials: true
  end
end
```

## Protection Against Common Vulnerabilities

### SQL Injection
- Always use parameterized queries and Active Record methods
- Avoid executing raw SQL when possible

### Cross-Site Scripting (XSS)
- Sanitize all user-generated content before output
- Use Rails' built-in HTML sanitizers

### Cross-Site Request Forgery (CSRF)
- For non-API endpoints, ensure `protect_from_forgery` is enabled
- For API endpoints, use token-based authentication

### Mass Assignment
- Use strong parameters to whitelist allowed parameters

## Secrets Management

- All sensitive information is stored as Docker secrets
- Credentials are never committed to version control
- Create a `.env.example` file with placeholder values
- Production credentials are managed through a proper secrets management service (e.g., AWS Secrets Manager)

## Regular Security Updates

- Keep all dependencies updated
- Use `bundle audit` to check for security vulnerabilities
- Set up automated security scanning in CI pipeline

## Logging and Monitoring

- Log authentication failures and security-related events
- Don't log sensitive information
- Set up alerting for suspicious activities

## Docker-Specific Security

- Run containers with least privileges
- Scan container images for vulnerabilities using tools like Trivy
- Use multi-stage builds to minimize attack surface
- Don't run containers as root

## API Documentation Security

- Don't include sensitive endpoints in public API documentation
- Use authorization in your API documentation tool

## Regular Security Audits

- Conduct regular security audits of the API
- Consider using a third-party security service for penetration testing 