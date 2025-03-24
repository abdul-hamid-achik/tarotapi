# Define cache store configuration for the application
# Uses Redis with connection pooling and replica support for optimal performance

# Log cache events in development
if Rails.env.development?
  cache_logger = ActiveSupport::Logger.new(STDOUT)
  cache_logger.formatter = Rails.logger.formatter
  cache_logger = ActiveSupport::TaggedLogging.new(cache_logger)
end

# Configure cache options based on environment
cache_options = {
  namespace: "tarotapi:cache",
  expires_in: 1.hour, # Default TTL
  race_condition_ttl: 10.seconds, # Prevent cache stampede
  error_handler: ->(method:, returning:, exception:) {
    Rails.logger.error("Redis Cache Error: #{exception.message}")
    Sentry.capture_exception(exception) if defined?(Sentry)
  }
}

# Use our Redis connection pools
if defined?(RedisPool)
  # Use replica pool for read operations if available
  cache_options[:pool] = RedisPool::REPLICA_POOL || RedisPool::CACHE_POOL

  # Configure fallback behavior
  cache_options[:error_handler] = ->(method:, returning:, exception:) {
    Rails.logger.error("Redis Cache Error: #{exception.message}")

    # Try falling back to primary if replica fails
    if RedisPool::REPLICA_POOL && cache_options[:pool] == RedisPool::REPLICA_POOL
      Rails.logger.info("Falling back to primary Redis for cache")
      cache_options[:pool] = RedisPool::CACHE_POOL
    end

    Sentry.capture_exception(exception) if defined?(Sentry)
  }
end

# Cache debug info in development only
if Rails.env.development?
  cache_options[:logger] = cache_logger
end

# Custom Redis cache store that uses our connection pool
class PooledRedisStore < ActiveSupport::Cache::RedisCacheStore
  def read_multi(*names)
    # Use replica for read_multi if available
    if defined?(RedisPool) && RedisPool::REPLICA_POOL
      options = merged_options(names.extract_options!)
      options[:pool] = RedisPool::REPLICA_POOL
      names = names.map { |name| normalize_key(name, options) }

      values = redis.with { |c| c.mget(*names) }
      results = {}

      names.zip(values).each do |name, value|
        if value
          entry = deserialize_entry(value)
          results[name] = entry.value unless entry.expired?
        end
      end

      results
    else
      super
    end
  end

  private

  def normalize_key(key, options)
    "tarot:#{super(key, options)}"
  end
end

# Configure cache stores
Rails.application.config.cache_store = :redis_cache_store, cache_options
Rails.application.config.action_controller.cache_store = :redis_cache_store, cache_options
