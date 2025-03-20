namespace :test do
  desc "Update specs to use new Card and Reading model names"
  task update_specs: :environment do
    puts "Updating tests to use Card instead of TarotCard and Reading instead of ReadingSession..."
    
    # Find all test files
    spec_files = Dir.glob("spec/**/*.rb")
    
    spec_files.each do |file|
      content = File.read(file)
      
      # Skip if file has no references to TarotCard or ReadingSession
      next unless content.include?("TarotCard") || content.include?("tarot_card") || 
                   content.include?("ReadingSession") || content.include?("reading_session")
      
      # Replace references
      updated_content = content.gsub("TarotCard", "Card")
                               .gsub("tarot_card", "card")
                               .gsub("ReadingSession", "Reading")
                               .gsub("reading_session", "reading")
      
      # Only write if changes were made
      if content != updated_content
        File.write(file, updated_content)
        puts "Updated: #{file}"
      end
    end
    
    # Find all test files
    test_files = Dir.glob("test/**/*.rb")
    
    test_files.each do |file|
      content = File.read(file)
      
      # Skip if file has no references to TarotCard or ReadingSession
      next unless content.include?("TarotCard") || content.include?("tarot_card") || 
                   content.include?("ReadingSession") || content.include?("reading_session")
      
      # Replace references
      updated_content = content.gsub("TarotCard", "Card")
                               .gsub("tarot_card", "card")
                               .gsub("ReadingSession", "Reading")
                               .gsub("reading_session", "reading")
      
      # Only write if changes were made
      if content != updated_content
        File.write(file, updated_content)
        puts "Updated: #{file}"
      end
    end
    
    puts "Test files updated successfully!"
  end
end 