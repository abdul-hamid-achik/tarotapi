# Tarot API Logging Guidelines

## Overview

The Tarot API uses a standardized logging approach based on `TarotLogger`, which combines structured logging (via SemanticLogger) with colorized console output and tarot-themed logging methods. This guide explains how to use the logging system across the codebase.

## Core Principles

1. **Always use the structured logging system** - Never use `puts`, `p`, or `Rails.logger.info` directly
2. **Include contextual data** with every log entry to make troubleshooting easier
3. **Use appropriate log levels** to distinguish between different types of events
4. **Follow consistent logging patterns** across the codebase

## Available Loggers

The codebase has been standardized to use a single unified logging system, with multiple interfaces:

- **TarotLogger** - The primary logging module that powers all other logging interfaces
- **TaskLogger** - For rake tasks (now a wrapper around TarotLogger)
- **DivinationLogger** - For tarot-themed logging (now a wrapper around TarotLogger)
- **Loggable** - A concern that can be included in classes for convenient logging

## Standard Log Levels

- **debug** - Verbose information useful for debugging (or `meditate` in tarot terminology)
- **info** - General operational information (or `reveal` in tarot terminology)
- **warn** - Warning conditions that don't prevent operation (or `obscure` in tarot terminology)
- **error** - Error conditions that prevent normal operation (or `prophecy` in tarot terminology)

## Tarot-Themed Log Levels

For better domain alignment, the logger supports tarot-themed method names:

- **divine** - Highest level information (bright green in console, equivalent to info)
- **reveal** - Regular information (cyan in console, equivalent to info)
- **obscure** - Warnings (yellow in console, equivalent to warn)
- **prophecy** - Errors (bright red in console, equivalent to error)
- **meditate** - Debug information (magenta in console, equivalent to debug)

## Logging in Different Components

### Controllers

Controllers automatically include the `Loggable` concern. Use it like this:

```ruby
# Direct methods
log_info("User signed up", { user_id: @user.id, plan: @user.plan })
log_error("Payment failed", { user_id: @user.id, error_code: result.error.code })

# Tarot-themed methods
divine("New reading created", { reading_id: @reading.id, spread: @reading.spread.name })
prophecy("Reading validation failed", { errors: @reading.errors.full_messages })

# Timed operations
with_logging("process_payment") do
  # Code that will be timed and logged
  process_payment
end

# Ritual-themed timed operations
divine_ritual("three_card_reading", { user_id: current_user.id }) do
  # Timed operation with automatic start/end logging
  perform_reading
end
```

### Models and Services

Include the `Loggable` concern in your models and services:

```ruby
class ReadingService
  include Loggable
  
  def perform
    log_info("Starting reading service", { cards: @cards.count })
    # or use tarot-themed methods
    divine("Reading initiated", { spread_name: @spread.name })
    
    # Timed operations
    with_logging("card_interpretation") do
      interpret_cards
    end
  end
end
```

### Rake Tasks

Use `TaskLogger` in rake tasks:

```ruby
namespace :tarot do
  desc "Import card data"
  task import_cards: :environment do
    TaskLogger.info("Starting card import", source: "csv_file")
    
    # Timed task execution with error handling
    TaskLogger.with_task_logging("tarot:import_cards") do
      # Your task logic here
    end
  end
end
```

### Background Jobs

Include `Loggable` in your job classes:

```ruby
class ProcessReadingJob < ApplicationJob
  include Loggable
  
  def perform(reading_id)
    reading = Reading.find(reading_id)
    log_info("Processing reading", { reading_id: reading.id, user_id: reading.user_id })
    
    # Use with_logging for operation timing
    with_logging("generate_interpretation", { reading_id: reading.id }) do
      # Your job logic
    end
  end
end
```

## Including Contextual Data

Always include relevant context with log entries to make them more useful:

- **IDs** - Include relevant record IDs (user_id, reading_id, etc.)
- **Status information** - Include success/failure and completion status
- **Counts and metrics** - Include relevant counts and performance metrics
- **Errors** - Include error messages and codes when logging errors

## Log Format

In production, logs are formatted as JSON for easier parsing by log aggregation tools. In development, logs are colorized for better readability.

Standard log entry fields:
- **timestamp** - ISO8601 formatted time
- **level** - Log level
- **name** - Logger name (class or component)
- **message** - Main log message
- **payload** - Additional contextual data
- **request_id** - Request ID for tracing requests
- **class_name** - Class name for context
- **duration** - For timed operations
- **user_id** - Current user ID (when available)

## Best Practices

1. **Be consistent** - Use the same logging pattern throughout the codebase
2. **Be specific** - Include enough context to understand what happened
3. **Be concise** - Keep log messages clear and to the point
4. **Use appropriate levels** - Don't log everything as info or error
5. **Structure your data** - Use structured data instead of embedding values in strings
6. **Use timed logging** - Wrap operations in `with_logging` or `divine_ritual` for automated timing

## Examples

### Good Examples

```ruby
# Good - structured data with context
log_info("User signup completed", { user_id: user.id, plan: user.plan, referral: params[:ref] })

# Good - using divine_ritual for timed operations
divine_ritual("major_arcana_reading", { user_id: current_user.id, spread: "celtic_cross" }) do
  perform_reading(@cards)
end
```

### Bad Examples

```ruby
# Bad - using puts
puts "User signed up: #{user.email}" 

# Bad - embedding data in strings
log_info("User #{user.id} signed up with plan #{user.plan}")

# Bad - not enough context
log_error("Operation failed")
```

## Viewing Logs

In development:
- Logs are displayed in the console with color-coding
- A log file is also generated in `log/development.log`

In production:
- Logs are formatted as JSON for log aggregation services
- The log level is set to INFO by default 