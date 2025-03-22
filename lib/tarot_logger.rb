require 'semantic_logger'
require 'rainbow'

# Unified logger for the Tarot API that combines structured logging with colorized output
module TarotLogger
  class << self
    def logger
      @logger ||= SemanticLogger['TarotAPI']
    end

    # Standard logging methods with structured data support
    def info(message, payload = {})
      logger.info(message, payload)
      console_output(:cyan, message, payload) unless Rails.env.production?
    end

    def debug(message, payload = {})
      logger.debug(message, payload)
      console_output(:magenta, message, payload) if ENV['DEBUG'] && !Rails.env.production?
    end

    def warn(message, payload = {})
      logger.warn(message, payload)
      console_output(:yellow, message, payload) unless Rails.env.production?
    end

    def error(message, payload = {})
      logger.error(message, payload)
      console_output(:red, message, payload, true) unless Rails.env.production?
    end

    # Divination-themed aliases for better domain context
    def divine(message, payload = {})
      info(message, payload.merge(ritual_type: 'divine'))
    end

    def reveal(message, payload = {})
      info(message, payload.merge(ritual_type: 'reveal'))
    end

    def obscure(message, payload = {})
      warn(message, payload.merge(ritual_type: 'obscure'))
    end

    def prophecy(message, payload = {})
      error(message, payload.merge(ritual_type: 'prophecy'))
    end

    def meditate(message, payload = {})
      debug(message, payload.merge(ritual_type: 'meditate'))
    end

    # Task logging with timing and error handling
    def with_task(task_name, payload = {})
      start_time = Time.now
      divine("Starting task", payload.merge(task: task_name))
      
      begin
        yield if block_given?
        duration = Time.now - start_time
        divine("Task completed", payload.merge(
          task: task_name,
          duration: duration.round(2)
        ))
      rescue => e
        duration = Time.now - start_time
        prophecy("Task failed", payload.merge(
          task: task_name,
          duration: duration.round(2),
          error: e.message,
          backtrace: e.backtrace.first(5)
        ))
        raise e
      end
    end

    # Ritual logging with timing and error handling (alias for with_task)
    def divine_ritual(name, payload = {})
      with_task(name, payload.merge(ritual: true))
    end

    private

    def console_output(color, message, payload = {}, bright = false)
      # Format the message for console output
      output = format_console_message(message, payload)
      
      # Apply color and brightness
      colored_output = if bright
        Rainbow(output).bright.send(color)
      else
        Rainbow(output).send(color)
      end

      # Output to console
      puts colored_output
    end

    def format_console_message(message, payload)
      return message if payload.empty?

      # Format payload for display
      payload_str = payload.map { |k, v| "#{k}=#{v.inspect}" }.join(' ')
      "#{message} | #{payload_str}"
    end
  end
end 