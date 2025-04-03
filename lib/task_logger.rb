# frozen_string_literal: true

require "logger"

# Simple logger for rake tasks with standard output formatting
module TaskLogger
  class << self
    def info(message, metadata = {})
      log(:info, message, metadata)
    end

    def warn(message, metadata = {})
      log(:warn, message, metadata)
    end

    def error(message, metadata = {})
      log(:error, message, metadata)
    end

    def debug(message, metadata = {})
      if ENV["DEBUG"] == "1"
        log(:debug, message, metadata)
      end
    end

    def divine(message, metadata = {})
      horizontal_rule
      info(message, metadata)
      horizontal_rule
    end

    def horizontal_rule
      puts "====================================================================="
    end

    def with_task_logging(task_name)
      divine("Starting task: #{task_name}")
      start_time = Time.now

      yield self if block_given?

      end_time = Time.now
      duration = end_time - start_time
      divine("Completed task: #{task_name} in #{duration.round(2)} seconds")
    rescue StandardError => e
      error("Task #{task_name} failed: #{e.message}")
      puts e.backtrace.join("\n")
      raise
    end

    private

    def log(level, message, metadata = {})
      level_str = level.to_s.upcase.ljust(5)
      timestamp = Time.now.strftime("%Y-%m-%d %H:%M:%S")

      # Print full message details when DEBUG is enabled
      if ENV["DEBUG"] == "1" && !metadata.empty?
        puts "[#{timestamp}] [#{level_str}] #{message}"
        puts "Metadata: #{metadata.inspect}"
      else
        puts "[#{timestamp}] [#{level_str}] #{message}"
      end
    end
  end
end
