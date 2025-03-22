# Rake Tasks Organization

This directory contains all rake tasks for the Tarot API project, organized by domain and functionality.

## Task Files Overview

### 1. `database.rake`
Database management and maintenance tasks:
- `db:check_config` - Check database configuration for all environments
- `db:setup_all` - Setup both development and test databases
- `db:pool:check` - Check database connection pool status
- `db:pool:clear_idle` - Clear idle connections

### 2. `deployment.rake`
Deployment and infrastructure tasks:
- `deploy:production` - Deploy to production with zero downtime
- `deploy:staging` - Deploy to staging environment
- `deploy:docker:*` - Docker-related tasks
- `deploy:aws:*` - AWS-specific tasks
- `deploy:monitoring:*` - Deployment monitoring tasks

### 3. `monitoring.rake`
System monitoring and logging tasks:
- `monitoring:health` - Check overall system health
- `monitoring:logs:*` - Log management tasks
- `monitoring:usage:*` - API usage tracking
- `monitoring:performance:*` - Performance metrics

### 4. `api.rake`
API-related tasks:
- `api:validate_all` - Run all API validation checks
- `api:keys:*` - API key management
- `api:docs:*` - API documentation generation
- `api:validate:*` - API validation tasks

### 5. `development.rake`
Development and testing tasks:
- `dev:setup` - Set up development environment
- `dev:clean` - Clean development environment
- `test:*` - Test execution tasks
- `ci:*` - Continuous integration tasks

## Common Task Groups

### Development Setup
```bash
# Set up development environment
rake dev:setup

# Clean development environment
rake dev:clean
```

### Testing
```bash
# Run all tests
rake test:all

# Run specific test types
rake test:unit
rake test:integration
rake test:system

# Generate test coverage report
rake test:coverage:report
```

### Deployment
```bash
# Deploy to production
rake deploy:production

# Deploy to staging
rake deploy:staging

# Build and push Docker images
rake deploy:docker:build
rake deploy:docker:push
```

### API Management
```bash
# Validate API
rake api:validate_all

# Generate API documentation
rake api:docs:generate

# Manage API keys
rake api:keys:list
rake api:keys:generate[name]
rake api:keys:revoke[key_id]
```

### Monitoring
```bash
# Check system health
rake monitoring:health

# Generate API usage report
rake monitoring:usage:report

# Analyze logs
rake monitoring:logs:analyze
```

## Best Practices

1. Always use the `TaskLogger` for consistent logging:
   ```ruby
   TaskLogger.info("Starting task...")
   TaskLogger.warn("Warning message")
   TaskLogger.error("Error occurred")
   ```

2. Include descriptive task descriptions:
   ```ruby
   desc "Detailed description of what the task does"
   task :my_task do
     # Task implementation
   end
   ```

3. Group related tasks under namespaces:
   ```ruby
   namespace :my_domain do
     # Related tasks here
   end
   ```

4. Use task dependencies appropriately:
   ```ruby
   task my_task: [:dependency1, :dependency2] do
     # Task implementation
   end
   ```

## Adding New Tasks

1. Identify the appropriate domain file for your task
2. Add your task within the relevant namespace
3. Include a clear description using `desc`
4. Use `TaskLogger` for output
5. Update this README if adding new task groups

## Task Organization Rules

1. Keep tasks focused and single-purpose
2. Use namespaces to organize related tasks
3. Provide clear feedback about task progress
4. Handle errors gracefully
5. Document task parameters and usage

## Notes

- All tasks use the `TaskLogger` for consistent output formatting
- Tasks that require the Rails environment include `:environment` dependency
- Complex tasks are broken down into smaller, focused subtasks
- Task names follow the pattern: `domain:action` or `domain:subdomain:action` 