namespace :rename_models do
  desc "Run all tasks needed to rename TarotCard to Card and ReadingSession to Reading"
  task run_all: :environment do
    puts "Starting comprehensive model renaming process..."
    
    # Step 1: Run migrations
    puts "Running migrations..."
    Rake::Task["db:migrate"].invoke
    
    # Step 2: Update specs
    puts "Updating test files..."
    Rake::Task["test:update_specs"].invoke
    
    # Step 3: Clean up old files
    puts "Cleaning up old files..."
    [
      "app/models/tarot_card.rb",
      "app/models/reading_session.rb",
      "app/controllers/api/v1/tarot_cards_controller.rb",
      "app/controllers/api/v1/reading_sessions_controller.rb",
      "app/serializers/tarot_card_serializer.rb",
      "app/serializers/reading_session_serializer.rb"
    ].each do |file|
      if File.exist?(file)
        File.delete(file)
        puts "Deleted: #{file}"
      end
    end
    
    puts "\nModel renaming process completed successfully!"
    puts "You should now be able to use Card and Reading models instead of TarotCard and ReadingSession."
    puts "Remember to run your tests to make sure everything works correctly."
  end
end 