require 'loki-logger'
require 'lograge'

# Configure Loki logger
if ENV['LOKI_URL'].present?
  loki_logger = LokiLogger.new(
    url: ENV['LOKI_URL'],
    job_name: 'tarot-api',
    labels: {
      environment: Rails.env,
      service: 'tarot-api',
      version: ENV['RELEASE_VERSION'] || '0.1.0'
    },
    flush_interval: Rails.env.production? ? 10 : 1, # Seconds
    max_batch_size: 100,
    retry_count: 3
  )

  # Add Loki logger to Rails logger
  Rails.logger.extend(ActiveSupport::Logger.broadcast(loki_logger))
end

# Configure Lograge for structured logging
Rails.application.configure do
  config.lograge.enabled = true
  config.lograge.base_controller_class = ['ActionController::API', 'ActionController::Base']
  
  # Keep original Rails logging in development
  config.lograge.keep_original_rails_log = Rails.env.development?
  
  # Add custom fields to all logs
  config.lograge.custom_options = lambda do |event|
    {
      time: Time.now.utc,
      trace_id: OpenTelemetry::Trace.current_span.context.trace_id,
      span_id: OpenTelemetry::Trace.current_span.context.span_id,
      host: event.payload[:host],
      user_id: event.payload[:user_id],
      params: event.payload[:params].except(*Rails.application.config.filter_parameters),
      exception: event.payload[:exception]&.first,
      exception_message: event.payload[:exception]&.last,
      redis_replica_used: event.payload[:redis_replica_used],
      db_replica_used: event.payload[:db_replica_used]
    }.compact
  end

  # Add SQL query logging
  config.lograge_sql.extract_event = Proc.new do |event|
    { 
      name: event.payload[:name],
      duration: event.duration.to_f.round(2),
      sql: event.payload[:sql],
      replica: event.payload[:replica]
    }
  end
  
  config.lograge_sql.formatter = Proc.new do |sql_queries|
    sql_queries
  end
end

# Add custom logging methods
module CustomLogging
  def log_error(error, context = {})
    error_data = {
      error_class: error.class.name,
      error_message: error.message,
      backtrace: error.backtrace&.first(5),
      context: context
    }

    Rails.logger.error(error_data)
  end

  def log_performance(operation, duration, context = {})
    perf_data = {
      operation: operation,
      duration_ms: duration.round(2),
      context: context
    }

    Rails.logger.info(perf_data)
  end
end

# Include custom logging in application controller
ActiveSupport.on_load(:action_controller) do
  include CustomLogging
end 