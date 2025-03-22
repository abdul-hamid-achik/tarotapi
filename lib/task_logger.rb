require 'semantic_logger'

# Define a helper for rake task logging
module TaskLogger
  class << self
    def logger
      @logger ||= SemanticLogger["TaskRunner"]
    end

    def info(message, payload = {})
      logger.info(message, payload)
    end

    def error(message, payload = {})
      logger.error(message, payload)
    end
    
    def warn(message, payload = {})
      logger.warn(message, payload)
    end
    
    def debug(message, payload = {})
      logger.debug(message, payload)
    end

    def with_task_logging(task_name)
      start_time = Time.now
      info("Starting task", task: task_name)
      begin
        yield if block_given?
        duration = Time.now - start_time
        info("Task completed", task: task_name, duration: duration.round(2))
      rescue => e
        duration = Time.now - start_time
        error("Task failed", 
              task: task_name, 
              duration: duration.round(2), 
              error: e.message,
              backtrace: e.backtrace.first(5))
        raise e
      end
    end
  end
end 