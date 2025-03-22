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
gem "stripe"

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

# api documentation
gem "rswag-api"
gem "redoc-rails"

# colorized output for rake tasks
gem "rainbow", "~> 3.1"

# structured logging
gem "lograge", "~> 0.14.0"
gem "semantic_logger", "~> 4.15"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri mingw x64_mingw ]

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false

  # api documentation dependencies for development
  gem "rspec-rails"
  gem "rswag-specs", group: [ :development, :test ]

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
