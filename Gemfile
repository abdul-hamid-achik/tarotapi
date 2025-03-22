source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.0.2"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Connection pooling and database monitoring
gem "connection_pool", "~> 2.4"  # Robust connection pooling
gem "pghero", "~> 3.4"           # PostgreSQL metrics and insights
gem "redis-client", "~> 0.19"    # Modern Redis client with built-in connection pooling

# Health checks and monitoring
gem "okcomputer", "~> 1.18"      # Comprehensive health check endpoints with authentication

# OpenTelemetry for monitoring and tracing
gem "opentelemetry-sdk"          # Base OpenTelemetry SDK
gem "opentelemetry-exporter-otlp" # OTLP exporter for OpenTelemetry
gem "opentelemetry-instrumentation-all" # Auto-instrumentation for all supported gems
gem "opentelemetry-semantic_conventions" # Standard semantic conventions
gem "lograge-sql"               # SQL query logging for lograge

# Deployment tools
gem "kamal", require: false  # Container deployment

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# gem "image_processing", "~> 1.2"

# Use Rack CORS for handling Cross-Origin Resource Sharing (CORS), making cross-origin Ajax possible
gem "rack-cors"

# authentication and authorization gems
gem "jwt"
gem "devise", "~> 4.9"
gem "devise_token_auth", "~> 1.2"
gem "omniauth", "~> 2.1"
gem "stripe"
gem "pay", "~> 8.3.0"
gem "pundit", "~> 2.3"  # For policy-based authorization

# llm and ai related gems
gem "ruby-openai", "~> 8.0.0"
gem "langchain"
gem "tokenizers"
gem "redis", ">= 4.0.1"
gem "sidekiq"

# api related
gem "jsonapi-serializer"
gem "oj"
gem "rack-attack"

# active storage
gem "aws-sdk-s3", require: false

# API documentation
gem "rswag-api"
gem "rswag-ui"
gem "rswag-specs", group: [ :development, :test ]

# colorized output for rake tasks and console colors
gem "rainbow", "~> 3.1"

# Logging and monitoring
gem "semantic_logger", "~> 4.15"  # Structured logging with JSON support
gem "lograge", "~> 0.14.0"       # Request logging in JSON format
gem "http_logger", "~> 0.7"      # HTTP request logging

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri mingw x64_mingw ]

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false

  # api documentation dependencies for development
  gem "rspec-rails"

  # load environment variables from .env file
  # Using standard dotenv for Rails 8 compatibility
  gem "dotenv-rails", "~> 3.1.7"

  # test coverage reporting
  gem "simplecov", require: false

  # testing gems
  gem "cucumber"
  gem "cucumber-rails", require: false
  gem "database_cleaner-active_record"
  gem "factory_bot_rails"
  gem "faker"
  gem "vcr"
  gem "webmock"
  gem "shoulda-matchers"

  # Database connection analysis
  gem "bullet", "~> 7.1"    # Detect and fix N+1 queries

  # security auditing
  gem "ruby_audit"

  # OpenAPI parser
  gem "openapi_parser"
end

# aws services
gem "aws-sdk-ssm", "~> 1.0"

# ai integration
# Commenting out due to ARM compatibility issues in Docker builds
# gem "llama_cpp"  # Local LLM integration

gem "makara", "~> 0.5.1"
