class DatabaseHealthcheck
  include Loggable

  class << self
    # Check database connection health and restore if necessary
    def check_connection
      begin
        result = ActiveRecord::Base.connection.execute("SELECT 1 as alive").first["alive"] == 1

        if result
          log_debug("Database connection is healthy") if Rails.env.development?
          true
        else
          log_warn("Database connection returned unexpected result", { result: result })
          false
        end
      rescue => e
        log_error("Database connection error detected", {
          error: e.message,
          error_class: e.class.name,
          connection_config: sanitized_connection_config
        })
        false
      end
    end

    # Verify connection pool health
    def check_pool_health
      pool = ActiveRecord::Base.connection_pool

      begin
        stats = {
          size: pool.size,
          connections: pool.connections.size,
          active: pool.connections.count(&:in_use?),
          idle: pool.connections.count { |c| !c.in_use? },
          waiting: pool.num_waiting_in_queue
        }

        # Calculate usage percentages for better observability
        stats[:usage_percent] = ((stats[:active].to_f / stats[:size]) * 100).round(1)
        stats[:status] = stats[:usage_percent] > 80 ? "high_load" : "normal"

        issues = []
        issues << "high_usage" if stats[:usage_percent] > 85
        issues << "queue_waiting" if stats[:waiting] > 0
        issues << "connection_limit_approaching" if stats[:active] >= stats[:size] - 1

        if issues.any?
          log_warn("Connection pool health issues detected", {
            issues: issues,
            stats: stats
          })

          # Try recovery if we're approaching saturation
          recover_connection_pool if stats[:usage_percent] > 90

          false
        else
          log_debug("Connection pool is healthy: #{stats.inspect}") if Rails.env.development?
          true
        end
      rescue => e
        log_error("Error checking connection pool health", {
          error: e.message,
          error_class: e.class.name,
          backtrace: e.backtrace&.first(3)
        })
        false
      end
    end

    # Verify and clean up all connections in the pool
    def verify_connections
      pool = ActiveRecord::Base.connection_pool

      initial_count = pool.connections.size
      bad_connections = []

      begin
        pool.connections.each do |conn|
          begin
            # Test the connection with a simple query
            unless conn.active? && conn.select_value("SELECT 1") == 1
              bad_connections << conn
            end
          rescue => e
            log_warn("Removing bad connection from pool", { error: e.message })
            bad_connections << conn
          end
        end

        # Remove bad connections
        bad_connections.each do |conn|
          pool.remove(conn)
        end

        if bad_connections.any?
          log_info("Removed #{bad_connections.size} bad connections from pool", {
            total_before: initial_count,
            total_after: pool.connections.size,
            pool_size: pool.size
          })
        else
          log_debug("All #{initial_count} connections verified successfully") if Rails.env.development?
        end

        true
      rescue => e
        log_error("Error verifying connections", {
          error: e.message,
          error_class: e.class.name,
          backtrace: e.backtrace&.first(3)
        })
        false
      end
    end

    # Recover connection pool by clearing bad connections
    def recover_connection_pool
      pool = ActiveRecord::Base.connection_pool

      divine_ritual("connection_pool_recovery") do
        log_info("Attempting connection pool recovery", {
          size: pool.size,
          active: pool.connections.count(&:in_use?),
          idle: pool.connections.count { |c| !c.in_use? }
        })

        verify_connections

        log_info("Connection pool recovery completed", {
          size: pool.size,
          active: pool.connections.count(&:in_use?),
          idle: pool.connections.count { |c| !c.in_use? }
        })
      end
    end

    private

    def sanitized_connection_config
      config = ActiveRecord::Base.connection_config.dup
      # Remove sensitive information
      config.except(:password)
    end
  end
end
