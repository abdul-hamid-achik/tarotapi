require 'connection_pool'
require 'redis'

# Redis connection pooling configuration
# Optimized for AWS Fargate with replica support
module RedisPool
  # Calculate the optimal Redis pool size
  # More conservative for Fargate environment
  def self.optimal_pool_size
    # Base this on a combination of web concurrency and worker processes
    web_concurrency = ENV.fetch("WEB_CONCURRENCY") { 2 }.to_i
    threads_per_process = ENV.fetch("RAILS_MAX_THREADS") { 5 }.to_i
    sidekiq_size = ENV.fetch("SIDEKIQ_CONCURRENCY") { 10 }.to_i
    
    # Calculate total pool size with more conservative approach for Fargate
    total_size = (web_concurrency * threads_per_process) + (sidekiq_size / 2)
    
    # Add a smaller buffer for other processes
    total_size += 2
    
    # Cap it at a reasonable maximum for Fargate
    [total_size, 20].min
  end

  # Configure Redis URLs based on environment
  def self.primary_redis_url
    ENV.fetch("REDIS_PRIMARY_URL") { ENV.fetch("REDIS_URL") { "redis://localhost:6379/0" } }
  end

  def self.replica_redis_url
    return nil unless ENV["REDIS_REPLICA_ENABLED"] == "true"
    ENV.fetch("REDIS_REPLICA_URL") { nil }
  end
  
  # Redis connection pool for cache with replica support
  CACHE_POOL = ConnectionPool.new(size: optimal_pool_size, timeout: 3) do
    Redis.new(
      url: primary_redis_url,
      connect_timeout: 1.0,
      read_timeout: 1.0,
      write_timeout: 1.0,
      reconnect_attempts: 2,
      tcp_keepalive: 60
    )
  end

  # Redis replica pool for read operations
  REPLICA_POOL = if replica_redis_url
    ConnectionPool.new(size: (optimal_pool_size * 1.5).to_i, timeout: 3) do
      Redis.new(
        url: replica_redis_url,
        connect_timeout: 1.0,
        read_timeout: 1.0,
        write_timeout: 1.0,
        reconnect_attempts: 2,
        tcp_keepalive: 60,
        readonly: true
      )
    end
  end
  
  # Redis connection pool for Rack::Attack (always uses primary)
  THROTTLING_POOL = ConnectionPool.new(size: (optimal_pool_size / 2).ceil, timeout: 2) do
    Redis.new(
      url: primary_redis_url,
      connect_timeout: 0.5,
      read_timeout: 0.5,
      write_timeout: 0.5,
      reconnect_attempts: 1,
      db: 1
    )
  end
  
  # Redis connection pool for Sidekiq (always uses primary)
  SIDEKIQ_POOL = ConnectionPool.new(size: ENV.fetch("SIDEKIQ_CONCURRENCY") { 10 }.to_i + 2, timeout: 3) do
    Redis.new(
      url: primary_redis_url,
      connect_timeout: 1.0,
      read_timeout: 1.0,
      write_timeout: 1.0,
      reconnect_attempts: 2,
      db: 2
    )
  end
  
  # Helper method to safely execute Redis operations with replica support
  def self.with_redis(pool = CACHE_POOL, &block)
    # Try replica for read operations if available
    if REPLICA_POOL && !block.binding.local_variable_defined?(:write_operation)
      pool = REPLICA_POOL
    end

    pool.with do |redis|
      begin
        yield redis
      rescue Redis::BaseError => e
        Rails.logger.error "Redis Error: #{e.class} - #{e.message}"
        # Fall back to primary if replica fails
        if pool == REPLICA_POOL
          Rails.logger.info "Falling back to primary Redis"
          CACHE_POOL.with { |primary| yield primary }
        else
          raise if Rails.env.development? || Rails.env.test?
          nil
        end
      end
    end
  end
  
  # Setup monitoring for Redis connection health
  if Rails.env.production?
    Thread.new do
      loop do
        begin
          sleep 30 # Check more frequently in Fargate
          
          # Check each pool and record metrics
          pools = {
            cache: CACHE_POOL,
            replica: REPLICA_POOL,
            throttling: THROTTLING_POOL,
            sidekiq: SIDEKIQ_POOL
          }.compact

          pools.each do |name, pool|
            next unless pool.respond_to?(:available)
            
            available = pool.available
            total = pool.size
            used = total - available
            
            # Log if reaching capacity with lower threshold for Fargate (60%)
            if used.to_f / total > 0.6
              Rails.logger.warn "#{name.to_s.capitalize} Redis pool nearing capacity: #{used}/#{total} connections used"
            end
          end
        rescue => e
          Rails.logger.error "Redis pool monitoring error: #{e.message}"
        end
      end
    end
  end
end

# Configure Redis Attack to use our connection pool
Rack::Attack.cache.store = RedisPool::THROTTLING_POOL 