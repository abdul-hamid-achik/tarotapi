namespace :rename do
  desc "rename card_reading to reading and tarot_card to card throughout the project"
  task :refactor => :environment do
    puts "starting rename operation..."
    
    # rename files and directories
    puts "renaming files and directories..."
    # card_reading to reading
    `find . -type f -not -path "*/\\.*" -not -path "*/node_modules/*" -not -path "*/tmp/*" -exec grep -l "card_reading" {} \\; | xargs sed -i 's/card_reading/reading/g'`
    `find . -type f -not -path "*/\\.*" -not -path "*/node_modules/*" -not -path "*/tmp/*" -exec grep -l "CardReading" {} \\; | xargs sed -i 's/CardReading/Reading/g'`
    
    # tarot_card to card
    `find . -type f -not -path "*/\\.*" -not -path "*/node_modules/*" -not -path "*/tmp/*" -exec grep -l "tarot_card" {} \\; | xargs sed -i 's/tarot_card/card/g'`
    `find . -type f -not -path "*/\\.*" -not -path "*/node_modules/*" -not -path "*/tmp/*" -exec grep -l "TarotCard" {} \\; | xargs sed -i 's/TarotCard/Card/g'`
    
    # rename directories and files
    puts "renaming actual files and directories..."
    `find . -depth -name "*card_reading*" -execdir bash -c 'mv "$1" "${1//card_reading/reading}"' bash {} \\;`
    `find . -depth -name "*tarot_card*" -execdir bash -c 'mv "$1" "${1//tarot_card/card}"' bash {} \\;`
    
    puts "rename operation completed"
  end
  
  desc "generate migration to rename database tables and columns"
  task :generate_migrations => :environment do
    puts "generating migrations..."
    
    # create table rename migrations
    `rails g migration rename_card_readings_to_readings`
    `rails g migration rename_tarot_cards_to_cards`
    
    puts "migrations generated - please edit them to include the proper rename statements"
  end
end 