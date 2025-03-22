# PostgreSQL connection pool optimization for AWS Fargate
# Complementing the general connection pool management

ActiveSupport.on_load(:active_record) do
  # PostgreSQL-specific connection configuration
  config = ActiveRecord::Base.connection_db_config

  begin
    # Only apply these optimizations if using PostgreSQL
    if defined?(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter) &&
       ActiveRecord::Base.connection.is_a?(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter)

      # Set statement timeout to prevent long-running queries
      # This is important for connection pool health
      ActiveRecord::Base.connection.execute("SET statement_timeout = '30s'")

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
              total = conn.size
              busy = conn.connections.count { |c| c.in_use? }
              idle = total - busy

              # Log the stats
              Rails.logger.info("PostgreSQL connection pool stats: total=#{total} busy=#{busy} idle=#{idle}")
            rescue => e
              Rails.logger.error("Error checking connection pool: #{e.message}")
            end
          end
        end
      end

      # Add a shutdown hook to properly close connections when the application stops
      # This prevents connection leaks during Fargate task termination
      at_exit do
        Rails.logger.info("Closing all PostgreSQL connections...")
        ActiveRecord::Base.connection_pool.disconnect!
      end
    end
  rescue ActiveRecord::NoDatabaseError => e
    Rails.logger.warn("Database not yet created. Skipping PostgreSQL optimizations: #{e.message}")
  rescue => e
    Rails.logger.error("Error during PostgreSQL connection pool setup: #{e.message}")
  end

  # NOTE: Connection pool idle_timeout should be configured in database.yml:
  #
  # production:
  #   adapter: postgresql
  #   database: my_database
  #   pool: 5
  #   idle_timeout: 120 # seconds to wait before removing idle connections
  #   checkout_timeout: 5 # seconds to wait for a connection before timeout

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
end
