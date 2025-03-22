require "opentelemetry/sdk"
require "opentelemetry/exporter/otlp"
require "opentelemetry/instrumentation/all"

# Only enable OpenTelemetry in production to avoid "Unable to export spans" errors in development
if Rails.env.production?
  begin
    # Configure OpenTelemetry SDK
    OpenTelemetry::SDK.configure do |c|
      # Configure the OTLP exporter (Tempo for traces)
      c.service_name = "tarot-api"
      c.service_version = ENV["RELEASE_VERSION"] || "0.1.0"

      # Use OTLP exporter for traces
      c.use_all() # Auto-instrument all supported gems

      # Configure span processor with batching
      span_processor = OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor.new(
        OpenTelemetry::Exporter::OTLP::Exporter.new(
          endpoint: ENV.fetch("OTEL_EXPORTER_OTLP_ENDPOINT", "http://tempo:4318/v1/traces"),
          headers: {
            "Authorization" => ENV["OTEL_EXPORTER_OTLP_HEADERS"]
          }.compact
        )
      )
      c.add_span_processor(span_processor)

      # Note: Sampler configuration removed as it's not compatible with current version
      # We'll use the default sampling behavior instead
    end

    # Add custom attributes to all spans
    OpenTelemetry.tracer_provider.on_tracer_created do |tracer|
      OpenTelemetry::SDK::Trace::Tracer.prepend(Module.new do
        def in_span(name, attributes: nil, kind: nil, links: nil, start_timestamp: nil, end_timestamp: nil, with_parent: nil, with_parent_context: nil)
          attributes ||= {}
          attributes["deployment.environment"] = Rails.env
          attributes["service.name"] = "tarot-api"
          attributes["service.version"] = ENV["RELEASE_VERSION"] || "0.1.0"

          super(name, attributes: attributes, kind: kind, links: links, start_timestamp: start_timestamp, end_timestamp: end_timestamp, with_parent: with_parent, with_parent_context: with_parent_context)
        end
      end)
    end

    # Configure error handling
    OpenTelemetry.error_handler = lambda do |exception:, message: nil, scope: nil, context: nil|
      Rails.logger.error("OpenTelemetry error: #{message || exception.message}")

      # Create an error event if we have a current span
      begin
        span = OpenTelemetry::Trace.current_span
        if span && !span.is_recording?
          attributes = {
            "error.type" => exception.class.name,
            "error.message" => exception.message,
            "error.stack_trace" => exception.backtrace&.join("\n"),
            "service.name" => "tarot-api",
            "deployment.environment" => Rails.env
          }

          # Add custom attributes for better error tracking
          if scope
            attributes["code.namespace"] = scope.class.name
            attributes["code.function"] = scope.try(:action_name)
          end

          # Record the error event
          span.add_event(
            "exception",
            attributes: attributes,
            timestamp: Time.now.to_i
          )
        end
      rescue => e
        Rails.logger.error("Error while handling OpenTelemetry error: #{e.message}")
      end
    end

    # Configure custom instrumentation for Redis operations
    if defined?(RedisPool)
      module RedisInstrumentation
        def self.instrument_redis_pool
          RedisPool.singleton_class.prepend(Module.new do
            def with_redis(pool = CACHE_POOL, &block)
              tracer = OpenTelemetry.tracer_provider.tracer("redis")

              tracer.in_span("redis.operation") do |span|
                span.set_attribute("db.system", "redis")
                span.set_attribute("db.operation", "execute")
                span.set_attribute("net.peer.name", pool == REPLICA_POOL ? "redis-replica" : "redis-primary")

                super
              end
            end
          end)
        end
      end

      RedisInstrumentation.instrument_redis_pool
    end
  rescue => e
    Rails.logger.error("Failed to initialize OpenTelemetry: #{e.message}")
  end
else
  Rails.logger.info("OpenTelemetry disabled in #{Rails.env} environment") if defined?(Rails.logger)
end
