require "rainbow"
require_relative "tarot_logger"

# A tarot-themed logger for the Tarot API
module DivinationLogger
  class << self
    # Divine - highest level, for important information (green)
    def divine(message)
      TarotLogger.divine(message)
    end

    # Reveal - for regular information (cyan)
    def reveal(message)
      TarotLogger.info(message)
    end

    # Obscure - for warnings (yellow)
    def obscure(message)
      TarotLogger.warn(message)
    end

    # Prophecy - for errors (red)
    def prophecy(message)
      TarotLogger.error(message)
    end

    # For debugging (magenta)
    def meditate(message)
      TarotLogger.debug(message) if ENV["DEBUG"]
    end

    # Optional block-style for timing operations
    def divine_ritual(name)
      start_time = Time.now
      divine("🔮 Beginning ritual: #{name}")
      begin
        yield if block_given?
        duration = Time.now - start_time
        divine("✨ Ritual completed: #{name} (#{duration.round(2)}s)")
      rescue => e
        duration = Time.now - start_time
        prophecy("🌑 Ritual failed: #{name} (#{duration.round(2)}s)")
        prophecy("Error: #{e.message}")
        prophecy(e.backtrace.first(5).join("\n"))
        raise e
      end
    end
  end
end
