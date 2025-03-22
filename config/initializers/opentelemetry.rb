require 'opentelemetry/sdk'
require 'opentelemetry/exporter/otlp'
require 'opentelemetry/instrumentation/all'

# Configure OpenTelemetry SDK
OpenTelemetry::SDK.configure do |c|
  # Configure the OTLP exporter (Tempo for traces)
  c.service_name = 'tarot-api'
  c.service_version = ENV['RELEASE_VERSION'] || '0.1.0'

  # Use OTLP exporter for traces
  c.use_all() # Auto-instrument all supported gems

  # Configure span processor with batching
  span_processor = OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor.new(
    OpenTelemetry::Exporter::OTLP::Exporter.new(
      endpoint: ENV.fetch('OTEL_EXPORTER_OTLP_ENDPOINT', 'http://tempo:4318/v1/traces'),
      headers: {
        'Authorization' => ENV['OTEL_EXPORTER_OTLP_HEADERS']
      }.compact
    )
  )
  c.add_span_processor(span_processor)

  # Configure sampling (use parent-based sampling in production)
  if Rails.env.production?
    c.sampler = OpenTelemetry::SDK::Trace::Samplers::ParentBased.new(
      root: OpenTelemetry::SDK::Trace::Samplers::TraceIdRatioBased.new(0.1) # Sample 10% of traces
    )
  else
    c.sampler = OpenTelemetry::SDK::Trace::Samplers::AlwaysOn.new
  end

  # Add custom attributes to all spans
  c.add_span_processor(
    Class.new(OpenTelemetry::SDK::Trace::SpanProcessor) do
      def on_start(span, context)
        span.set_attribute('deployment.environment', Rails.env)
        span.set_attribute('service.name', 'tarot-api')
        span.set_attribute('service.version', ENV['RELEASE_VERSION'] || '0.1.0')
      end
    end.new
  )
end

# Configure error tracking
OpenTelemetry::SDK.configure do |c|
  error_handler = lambda do |exception:, message: nil, scope: nil, context: nil|
    Rails.logger.error("OpenTelemetry Error: #{message || exception.message}")
    
    # Create an error event
    span_context = OpenTelemetry::Trace.current_span.context
    attributes = {
      'error.type' => exception.class.name,
      'error.message' => exception.message,
      'error.stack_trace' => exception.backtrace&.join("\n"),
      'service.name' => 'tarot-api',
      'deployment.environment' => Rails.env
    }

    # Add custom attributes for better error tracking
    if scope
      attributes['code.namespace'] = scope.class.name
      attributes['code.function'] = scope.try(:action_name)
    end

    # Record the error event
    OpenTelemetry::Trace.current_span.add_event(
      'exception',
      attributes: attributes,
      timestamp: Time.now.to_i
    )
  end

  c.error_handler = error_handler
end

# Configure custom instrumentation for Redis operations
module RedisInstrumentation
  def self.instrument_redis_pool
    RedisPool.singleton_class.prepend(Module.new do
      def with_redis(pool = CACHE_POOL, &block)
        tracer = OpenTelemetry.tracer_provider.tracer('redis')
        
        tracer.in_span("redis.operation") do |span|
          span.set_attribute('db.system', 'redis')
          span.set_attribute('db.operation', 'execute')
          span.set_attribute('net.peer.name', pool == REPLICA_POOL ? 'redis-replica' : 'redis-primary')
          
          super
        end
      end
    end)
  end
end

RedisInstrumentation.instrument_redis_pool if defined?(RedisPool) 