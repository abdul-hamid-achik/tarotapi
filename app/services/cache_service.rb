# Service for managing the application's cache
class CacheService
  class << self
    # Clear all caches for a specific model
    def clear_model_cache(model_class)
      cache_key = model_class.model_name.cache_key
      Rails.cache.delete_matched("#{cache_key}/*")
      Rails.logger.info("Cleared cache for #{model_class.name}")
    end

    # Clear all caches for a specific model instance
    def clear_instance_cache(record)
      cache_key = "#{record.class.model_name.cache_key}/#{record.id}"
      Rails.cache.delete(cache_key)
      Rails.logger.info("Cleared cache for #{record.class.name} ##{record.id}")
    end

    # Warm up the cache for frequently accessed data
    def warm_up_cache
      Rails.logger.info("Warming up the cache...")

      # Cache all major arcana cards
      Card.find_by_arcana_cached("major")

      # Cache all minor arcana cards
      Card.find_by_arcana_cached("minor")

      # Cache system spreads
      Spread.cached_query("system_spreads") do
        Spread.system.order(:name)
      end

      # Cache subscription plans
      SubscriptionPlan.cached_query("all_plans") do
        SubscriptionPlan.all.order(:price)
      end

      Rails.logger.info("Cache warm-up completed")
    end

    # Fetch with mutex lock to prevent cache stampede for expensive operations
    def fetch_with_lock(key, expires_in: 1.hour, &block)
      # First try to get it from the cache
      cached_value = Rails.cache.read(key)
      return cached_value if cached_value

      # If not in cache, use a mutex to ensure only one process regenerates the value
      mutex_key = "mutex:#{key}"
      got_lock = Rails.cache.write(mutex_key, true, unless_exist: true, expires_in: 30.seconds)

      if got_lock
        # We got the lock, so generate the value
        value = yield
        Rails.cache.write(key, value, expires_in: expires_in)
        Rails.cache.delete(mutex_key)
        value
      else
        # Another process is generating the value, wait a bit and try again
        sleep 0.1
        fetch_with_lock(key, expires_in: expires_in, &block)
      end
    end

    # Clear all caches (for use in rake tasks or admin functions)
    def clear_all_caches
      Rails.logger.info("Clearing all caches...")
      Rails.cache.clear
      Rails.logger.info("All caches cleared")
    end
  end
end
