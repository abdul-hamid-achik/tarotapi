require 'fileutils'
require_relative '../tarot_logger'

namespace :logger do
  desc "Migrate from old loggers to TarotLogger"
  task migrate: :environment do
    TarotLogger.with_task("logger:migrate") do
      # Search for files using old loggers
      old_logger_files = `git grep -l "DivinationLogger\\|TaskLogger" app lib`.split("\n")
      
      if old_logger_files.empty?
        TarotLogger.divine("No files found using old loggers")
        next
      end

      TarotLogger.reveal("Found #{old_logger_files.size} files using old loggers")
      
      old_logger_files.each do |file|
        TarotLogger.reveal("Processing #{file}")
        
        # Read file content
        content = File.read(file)
        
        # Create backup
        backup_file = "#{file}.bak"
        FileUtils.cp(file, backup_file)
        TarotLogger.debug("Created backup at #{backup_file}")
        
        # Replace old logger calls with new ones
        new_content = content
          .gsub('require_relative "../divination_logger"', 'require_relative "../tarot_logger"')
          .gsub('require_relative "../task_logger"', 'require_relative "../tarot_logger"')
          .gsub('DivinationLogger', 'TarotLogger')
          .gsub('TaskLogger', 'TarotLogger')
        
        # Write updated content
        File.write(file, new_content)
        TarotLogger.divine("Updated #{file}")
      end

      # Instructions for manual review
      TarotLogger.divine(<<~INSTRUCTIONS)
        Migration completed! Please:
        1. Review the changes in the affected files
        2. Run your test suite
        3. Remove the old logger files:
           - lib/divination_logger.rb
           - lib/task_logger.rb
        4. Delete backup files (*.bak) once verified
      INSTRUCTIONS
    end
  end

  desc "Show examples of using TarotLogger"
  task :examples do
    puts <<~EXAMPLES
      # Basic logging with structured data
      TarotLogger.info("Processing request", user_id: 123, action: "login")
      TarotLogger.error("Database connection failed", retries: 3, host: "db.example.com")

      # Divination-themed logging
      TarotLogger.divine("Starting card reading ritual")
      TarotLogger.reveal("Card drawn: The Fool")
      TarotLogger.obscure("Mercury is in retrograde")
      TarotLogger.prophecy("Invalid spread configuration")
      TarotLogger.meditate("Debug information") # Only shown when DEBUG=true

      # Task/Process logging with timing
      TarotLogger.with_task("import:cards") do
        # Your task code here
        # Automatically logs start/completion/failure with timing
      end

      # Ritual logging (alias for with_task)
      TarotLogger.divine_ritual("daily:card_reading") do
        # Your ritual code here
      end

      # Logging with additional context
      TarotLogger.info("User action", {
        user_id: 123,
        action: "draw_card",
        card: "The Fool",
        timestamp: Time.now.iso8601
      })
    EXAMPLES
  end
end 