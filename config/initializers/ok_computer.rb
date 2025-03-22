# OkComputer Configuration
# This gem provides a robust health check system with authentication

# Mount the health check at /health
OkComputer.mount_at = "health_checks"

# Require authentication for detailed checks
OkComputer.require_authentication = true

# Set username/password for authentication
# These should come from secure environment variables in production
OkComputer.username = ENV.fetch("HEALTH_CHECK_USERNAME") { "admin" }
OkComputer.password = ENV.fetch("HEALTH_CHECK_PASSWORD") { "tarot_health_check" }

# Register health checks
OkComputer::Registry.register "database", OkComputer::ActiveRecordCheck.new
OkComputer::Registry.register "redis", OkComputer::RedisCheck.new(url: ENV.fetch("REDIS_URL") { "redis://localhost:6379" })
OkComputer::Registry.register "sidekiq", OkComputer::SidekiqLatencyCheck.new(queue: "default")

# Add PostgreSQL connection pool check
class PostgreSQLConnectionPoolCheck < OkComputer::Check
  def check
    pool = ActiveRecord::Base.connection_pool
    stats = {
      size: pool.size,
      active: pool.connections.count(&:in_use?),
      idle: pool.connections.count { |c| !c.in_use? },
      waiting: pool.num_waiting_in_queue
    }

    # Calculate usage percentage
    usage_percent = (stats[:active].to_f / stats[:size]) * 100

    # Mark as failure if pool is almost saturated
    if usage_percent > 80
      mark_failure
      mark_message "Connection pool nearing capacity: #{usage_percent.round(1)}% used (#{stats[:active]}/#{stats[:size]})"
    else
      mark_message "Connection pool healthy: #{usage_percent.round(1)}% used (#{stats[:active]}/#{stats[:size]})"
    end
  end
end

OkComputer::Registry.register "pg_pool", PostgreSQLConnectionPoolCheck.new

# Add Redis connection pool check if we're using our custom Redis pool
if defined?(RedisPool)
  class RedisConnectionPoolCheck < OkComputer::Check
    def check
      check_pool("Primary", RedisPool::CACHE_POOL)
      check_pool("Replica", RedisPool::REPLICA_POOL) if RedisPool::REPLICA_POOL
    end

    private

    def check_pool(name, pool)
      return unless pool&.respond_to?(:available)

      stats = {
        size: pool.size,
        available: pool.available,
        in_use: pool.size - pool.available
      }

      # Calculate usage percentage
      usage_percent = (stats[:in_use].to_f / stats[:size]) * 100

      # Mark as failure if pool is almost saturated (60% for Fargate)
      if usage_percent > 60
        mark_failure
        mark_message "#{name} Redis pool nearing capacity: #{usage_percent.round(1)}% used (#{stats[:in_use]}/#{stats[:size]})"
      else
        mark_message "#{name} Redis pool healthy: #{usage_percent.round(1)}% used (#{stats[:in_use]}/#{stats[:size]})"
      end

      # Check actual Redis connection
      begin
        pool.with do |redis|
          result = redis.ping
          unless result == "PONG"
            mark_failure
            mark_message "#{name} Redis ping failed: #{result}"
          end
        end
      rescue => e
        mark_failure
        mark_message "#{name} Redis connection error: #{e.message}"
      end
    end
  end

  OkComputer::Registry.register "redis_pool", RedisConnectionPoolCheck.new
end

# Add public basic check for load balancers (no auth required)
class AppRunningCheck < OkComputer::Check
  def check
    mark_message "Application is running"
  end
end

OkComputer::Registry.register "default", AppRunningCheck.new
OkComputer.make_optional %w[sidekiq redis_pool]

# Make default check publicly accessible for load balancers
OkComputer.allow_in_read_only_mode = %w[default]
