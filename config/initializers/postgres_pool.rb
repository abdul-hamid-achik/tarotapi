# PostgreSQL connection pool optimization for AWS Fargate
# Complementing the general connection pool management

ActiveSupport.on_load(:active_record) do
  # PostgreSQL-specific connection configuration
  config = ActiveRecord::Base.connection_config

  # Only apply these optimizations if using PostgreSQL
  if defined?(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter) &&
     ActiveRecord::Base.connection.is_a?(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter)

    # Set statement timeout to prevent long-running queries
    # This is important for connection pool health
    ActiveRecord::Base.connection.execute("SET statement_timeout = '30s'")

    # Optimize prepared statement usage
    # For Fargate with a single source, we want to limit the number of prepared statements
    ActiveRecord::Base.connection.execute("SET max_prepared_transactions = 100")

    # Set client_min_messages to reduce logging noise
    ActiveRecord::Base.connection.execute("SET client_min_messages = 'warning'")

    # Log PostgreSQL connection pool status periodically
    if Rails.env.production?
      Thread.new do
        # Give the application time to fully initialize
        sleep 30

        loop do
          begin
            sleep 120 # Check every 2 minutes

            # Get current connection stats
            conn = ActiveRecord::Base.connection_pool
            stats = {
              pool_size: conn.size,
              active: conn.connections.count(&:in_use?),
              idle: conn.connections.count { |c| !c.in_use? },
              waiting: conn.num_waiting_in_queue
            }

            # Calculate usage percentage
            usage_percent = (stats[:active].to_f / stats[:pool_size]) * 100

            # Log warning if approaching capacity
            if usage_percent > 70
              Rails.logger.warn "PostgreSQL connection pool at #{usage_percent.round(1)}% capacity ⚠️: #{stats.inspect}"
            else
              Rails.logger.info "PostgreSQL connection pool status: #{stats.inspect}" if Rails.env.development?
            end

            # Check for potential connection leaks (high usage for extended period)
            if stats[:active] > stats[:pool_size] * 0.8 && stats[:waiting] > 0
              Rails.logger.warn "Potential PostgreSQL connection leak detected ⚠️ - " \
                               "high usage with waiting connections: #{stats.inspect}"
            end
          rescue => e
            Rails.logger.error "Error monitoring PostgreSQL connection pool: #{e.message}"
          end
        end
      end
    end
  end

  # Configure connection reaping which is crucial for Fargate deployments
  # as containers can be stopped or restarted at any time
  ActiveRecord::Base.connection_pool.reaping_frequency = 30 # seconds

  # Set a reasonable idle timeout for connections
  # For a single source database, we want to return idle connections promptly
  ActiveRecord::Base.connection_pool.idle_timeout = 120 # seconds

  # Add a shutdown hook to properly close connections when the application stops
  # This prevents connection leaks during Fargate task termination
  at_exit do
    begin
      ActiveRecord::Base.connection_pool.disconnect!
      Rails.logger.info "PostgreSQL connections properly closed on shutdown"
    rescue => e
      Rails.logger.error "Error disconnecting PostgreSQL connections: #{e.message}"
    end
  end
end

# If PgBouncer is not being used, add these notes about how to set it up
if Rails.env.development? && !ENV["PGBOUNCER_ENABLED"]
  Rails.logger.info <<~PGBOUNCER_NOTICE
    ================================================================================
    🔄 PostgreSQL Connection Pooling Notice 🔄

    For production Fargate deployments, consider using PgBouncer for connection pooling.
    This can be set up as a sidecar container in your task definition or as a separate service.

    Basic PgBouncer configuration in pgbouncer.ini:
    [databases]
    #{Rails.configuration.database_configuration[Rails.env]['database']} = host=#{Rails.configuration.database_configuration[Rails.env]['host']} port=#{Rails.configuration.database_configuration[Rails.env]['port'] || 5432}

    [pgbouncer]
    pool_mode = transaction
    max_client_conn = 100
    default_pool_size = 20
    reserve_pool_size = 5
    reserve_pool_timeout = 3
    server_reset_query = DISCARD ALL
    server_check_delay = 30
    server_check_query = SELECT 1
    ================================================================================
  PGBOUNCER_NOTICE
end
