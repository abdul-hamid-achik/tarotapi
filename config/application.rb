require_relative "boot"

require "rails/all"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_mailbox/engine"
require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"
# require "rails/test_unit/railtie"

# Require the middleware
require_relative "../app/middleware/reading_quota_middleware"
require_relative "../app/middleware/rate_limit_middleware"
require_relative "../app/middleware/api_usage_middleware"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module TarotApi
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # use rack attack for rate limiting
    config.middleware.use Rack::Attack

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks templates])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Add app/middleware to the eager load paths
    config.eager_load_paths << Rails.root.join("app/middleware")

    # Add app/models/test_support to the autoload paths for tests
    config.autoload_paths += %W[#{config.root}/app/models/test_support]

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
    config.api_only = true

    # allow test hosts
    config.hosts.clear
    config.hosts << "tarotapi.cards"
    config.hosts << "www.tarotapi.cards"
    config.hosts << "localhost"

    # Load middleware for API usage tracking and quotas
    config.middleware.use ApiUsageMiddleware
    config.middleware.use ReadingQuotaMiddleware
    config.middleware.use RateLimitMiddleware

    # Enable strict loading by default in development to catch N+1 queries early
    if Rails.env.development?
      config.active_record.strict_loading_by_default = true
      config.active_record.action_on_strict_loading_violation = :log # or :raise
    end

    # Since we're using ActiveStorage, we need to include the content types
    config.active_storage.content_types_to_serve_as_binary += [ "application/vnd.openxmlformats-officedocument.wordprocessingml.document", "application/vnd.ms-excel" ]

    # Skip pending migrations check for tests
    config.active_record.maintain_test_schema = false if Rails.env == "test"
  end
end
