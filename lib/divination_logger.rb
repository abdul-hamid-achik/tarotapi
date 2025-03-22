require "rainbow"

# A tarot-themed logger for the Tarot API
module DivinationLogger
  class << self
    # Divine - highest level, for important information (green)
    def divine(message)
      puts Rainbow(message).bright.green
    end

    # Reveal - for regular information (cyan)
    def reveal(message)
      puts Rainbow(message).cyan
    end

    # Obscure - for warnings (yellow)
    def obscure(message)
      puts Rainbow(message).yellow
    end

    # Prophecy - for errors (red)
    def prophecy(message)
      puts Rainbow(message).red.bright
    end

    # For debugging (magenta)
    def meditate(message)
      puts Rainbow(message).magenta if ENV["DEBUG"]
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
