# Makara configuration for read replicas
# This initializer configures Makara for primary/replica database setups

# Only load if the makara gem is available
if defined?(Makara)
  # Set up the Makara middleware for sticky connections
  Rails.application.config.middleware.use Makara::Middleware unless Rails.env.test?

  # Configure Makara logging in development
  if Rails.env.development?
    ActiveSupport::Notifications.subscribe("db.makara") do |_name, start, finish, _id, payload|
      duration = (finish - start) * 1000
      Rails.logger.debug "[Makara] #{payload[:method]} on role #{payload[:role]} (#{duration.round(1)}ms)" if payload[:role]
    end
  end

  # Configure Makara to work with OkComputer health checks
  if defined?(OkComputer)
    # Add a specific check for each database node
    if Rails.application.config.database_configuration[Rails.env].is_a?(Hash) &&
       Rails.application.config.database_configuration[Rails.env]["makara"]

      # Extract the connection configurations
      makara_config = Rails.application.config.database_configuration[Rails.env]["makara"]

      if makara_config && makara_config["connections"].is_a?(Array)
        makara_config["connections"].each do |conn|
          node_name = conn["name"]
          role = conn["role"]

          # Create a custom check for this specific database node
          OkComputer::Registry.register "db_#{role}_#{node_name}", OkComputer::ActiveRecordCheck.new(
            connection_name: node_name
          )
        end
      end
    end
  end

  # Define Makara Sidekiq middleware classes
  class SidekiqMakaraClientMiddleware
    def call(worker_class, job, queue, redis_pool)
      job["makara_context"] = Makara::Context.get_current if Makara::Context.get_current
      yield
    end
  end

  class SidekiqMakaraServerMiddleware
    def call(worker, job, queue)
      if job["makara_context"]
        Makara::Context.set_current(job["makara_context"])
        Makara::Context.get_current
      end

      yield
    ensure
      Makara::Context.clear_current
    end
  end

  # Configure Makara context to work in Sidekiq
  if defined?(Sidekiq)
    Sidekiq.configure_client do |config|
      config.client_middleware do |chain|
        chain.add SidekiqMakaraClientMiddleware
      end
    end

    Sidekiq.configure_server do |config|
      config.client_middleware do |chain|
        chain.add SidekiqMakaraClientMiddleware
      end

      config.server_middleware do |chain|
        chain.add SidekiqMakaraServerMiddleware
      end
    end
  end
end
