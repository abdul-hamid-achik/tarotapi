# Configure structured logging for the application
require "semantic_logger"
require "lograge"
require "socket"

Rails.application.configure do
  # Configure Lograge for request logging
  config.lograge.enabled = true
  config.lograge.formatter = Lograge::Formatters::Json.new
  config.lograge.custom_options = lambda do |event|
    exceptions = %w[controller action format id]
    {
      time: Time.now.iso8601,
      host: Socket.gethostname,
      pid: Process.pid,
      environment: Rails.env,
      request_id: event.payload[:request_id],
      params: event.payload[:params].except(*exceptions),
      custom_payload: event.payload[:custom_payload]
    }
  end

  # Configure Semantic Logger as the Rails logger
  SemanticLogger.application = Rails.application.class.module_parent_name
  SemanticLogger.add_appender(
    io: $stdout,
    formatter: :json
  )

  # Add Loki appender in non-development environments
  if Rails.env.production? || Rails.env.staging?
    loki_url = ENV.fetch("LOKI_URL", "http://loki.tarot-api.internal:3100")

    SemanticLogger.add_appender(
      appender: :http_json,
      url: "#{loki_url}/loki/api/v1/push",
      formatter: :json,
      application: Rails.application.class.module_parent_name,
      level: :info,
      metrics: %w[duration],
      backtrace_level: :error
    )
  end

  # Set log level based on environment
  config.log_level = case Rails.env
  when "production", "staging"
                      ENV.fetch("LOG_LEVEL", "info").to_sym
  else
                      ENV.fetch("LOG_LEVEL", "debug").to_sym
  end

  # Disable ActiveRecord SQL logging in production
  config.active_record.logger = nil if Rails.env.production?
end
