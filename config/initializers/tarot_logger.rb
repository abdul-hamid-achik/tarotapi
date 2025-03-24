require "semantic_logger"
require "rainbow"
require_relative "../../lib/tarot_logger"

# Configure SemanticLogger as the Rails logger
Rails.application.configure do
  config.semantic_logger.application = Rails.application.class.module_parent_name

  # Skip rails_semantic_logger if explicitly disabled (for CI or when having compatibility issues)
  if ENV["DISABLE_RAILS_SEMANTIC_LOGGER"].present? || Rails.env == "test"
    # Use standard semantic_logger without rails integration
    SemanticLogger.add_appender(io: STDOUT, formatter: :default)

    # Completely disable rails_semantic_logger ActiveRecord integration
    # to avoid the 'undefined method type for Symbol' error in Rails 8.0.2
    if defined?(RailsSemanticLogger) && defined?(RailsSemanticLogger::ActiveRecord)
      # Remove the ActiveRecord LogSubscriber to prevent binding errors
      ActiveSupport::LogSubscriber.log_subscribers.each do |subscriber|
        if subscriber.is_a?(RailsSemanticLogger::ActiveRecord::LogSubscriber)
          ActiveSupport::Notifications.notifier.listeners_for("sql.active_record").each do |listener|
            if listener.instance_variable_get(:@delegate) == subscriber
              ActiveSupport::Notifications.unsubscribe(listener)
            end
          end
        end
      end
    end
  else
    # Only use rails_semantic_logger configs if defined and available
    if defined?(config.rails_semantic_logger) && config.respond_to?(:rails_semantic_logger)
      # Bypass rails_semantic_logger functionality that's incompatible with Rails 8.0.2
      # We'll just use semantic_logger directly
    end
  end

  # Set log level based on environment
  config.log_level = case Rails.env
  when "production", "staging"
                       ENV.fetch("LOG_LEVEL", "info").to_sym
  else
                       ENV.fetch("LOG_LEVEL", "debug").to_sym
  end

  # Replace TaskLogger and DivinationLogger with TarotLogger for consistency
  # This monkey-patches the other loggers to use TarotLogger under the hood
  module TaskLogger
    class << self
      def logger
        TarotLogger.logger
      end

      def info(message, payload = {})
        TarotLogger.info(message, payload)
      end

      def error(message, payload = {})
        TarotLogger.error(message, payload)
      end

      def warn(message, payload = {})
        TarotLogger.warn(message, payload)
      end

      def debug(message, payload = {})
        TarotLogger.debug(message, payload)
      end

      def with_task_logging(task_name)
        TarotLogger.with_task(task_name) do
          yield if block_given?
        end
      end
    end
  end

  module DivinationLogger
    class << self
      def divine(message)
        TarotLogger.divine(message)
      end

      def reveal(message)
        TarotLogger.reveal(message)
      end

      def obscure(message)
        TarotLogger.obscure(message)
      end

      def prophecy(message)
        TarotLogger.prophecy(message)
      end

      def meditate(message)
        TarotLogger.meditate(message)
      end

      def divine_ritual(name)
        TarotLogger.divine_ritual(name) do
          yield if block_given?
        end
      end
    end
  end
end

# Set Rails.logger to use TarotLogger
Rails.logger = TarotLogger.logger

# Configure ActiveRecord logging
ActiveRecord::Base.logger = TarotLogger.logger

# Configure ActiveJob logging
if defined?(ActiveJob)
  ActiveJob::Base.logger = TarotLogger.logger
end

# Configure ActionCable logging
if defined?(ActionCable)
  ActionCable.server.config.logger = TarotLogger.logger
end
