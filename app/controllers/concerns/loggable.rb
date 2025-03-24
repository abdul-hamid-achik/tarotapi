module Loggable
  extend ActiveSupport::Concern

  # Default context to include with all log entries
  def log_context
    {
      class_name: self.class.name,
      request_id: Thread.current[:request_id]
    }
  end

  # Add additional context for controllers
  def controller_log_context
    return {} unless defined?(request)

    {
      ip: request.remote_ip,
      path: request.fullpath,
      method: request.method,
      user_id: try(:current_user)&.id
    }
  end

  # Standard logging methods
  def log_info(message, payload = {})
    TarotLogger.info(message, log_context.merge(payload))
  end

  def log_debug(message, payload = {})
    TarotLogger.debug(message, log_context.merge(payload))
  end

  def log_warn(message, payload = {})
    TarotLogger.warn(message, log_context.merge(payload))
  end

  def log_error(message, payload = {})
    TarotLogger.error(message, log_context.merge(payload))
  end

  # Tarot-themed aliases
  def divine(message, payload = {})
    TarotLogger.divine(message, log_context.merge(payload))
  end

  def reveal(message, payload = {})
    TarotLogger.reveal(message, log_context.merge(payload))
  end

  def obscure(message, payload = {})
    TarotLogger.obscure(message, log_context.merge(payload))
  end

  def prophecy(message, payload = {})
    TarotLogger.prophecy(message, log_context.merge(payload))
  end

  def meditate(message, payload = {})
    TarotLogger.meditate(message, log_context.merge(payload))
  end

  # Timed operation logging
  def with_logging(operation_name, payload = {})
    TarotLogger.with_task(operation_name, log_context.merge(payload)) do
      yield if block_given?
    end
  end

  # Ritual-themed timed operation (alias)
  def divine_ritual(ritual_name, payload = {})
    TarotLogger.divine_ritual(ritual_name, log_context.merge(payload)) do
      yield if block_given?
    end
  end

  # Include these methods at the class level too
  module ClassMethods
    def log_info(message, payload = {})
      TarotLogger.info(message, { class_name: name }.merge(payload))
    end

    def log_debug(message, payload = {})
      TarotLogger.debug(message, { class_name: name }.merge(payload))
    end

    def log_warn(message, payload = {})
      TarotLogger.warn(message, { class_name: name }.merge(payload))
    end

    def log_error(message, payload = {})
      TarotLogger.error(message, { class_name: name }.merge(payload))
    end

    # Tarot-themed aliases for class methods
    def divine(message, payload = {})
      TarotLogger.divine(message, { class_name: name }.merge(payload))
    end

    def reveal(message, payload = {})
      TarotLogger.reveal(message, { class_name: name }.merge(payload))
    end

    def obscure(message, payload = {})
      TarotLogger.obscure(message, { class_name: name }.merge(payload))
    end

    def prophecy(message, payload = {})
      TarotLogger.prophecy(message, { class_name: name }.merge(payload))
    end
  end
end
