require "semantic_logger"
require "rainbow"
require_relative "../../lib/tarot_logger"

# Configure SemanticLogger as the Rails logger
Rails.application.configure do
  config.semantic_logger.application = Rails.application.class.module_parent_name
  config.rails_semantic_logger.format = :json
  config.rails_semantic_logger.semantic = true

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
