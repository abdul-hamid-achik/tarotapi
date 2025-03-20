namespace :data do
  desc "seed the database with tarot cards and spreads"
  task seed: :environment do
    puts "seeding database with tarot cards and spreads..."
    
    # Get card data source
    cards_source = "db/seeds/cards.json"
    
    if File.exist?(cards_source)
      # Parse the card data
      puts "reading card data from #{cards_source}..."
      card_data = JSON.parse(File.read(cards_source))
      
      # Create the cards
      card_data.each do |card_attrs|
        puts "creating or updating card: #{card_attrs['name']}"
        
        # Find or initialize the card
        card = Card.find_or_initialize_by(name: card_attrs['name'])
        
        # Update attributes
        card.update!(
          number: card_attrs['number'],
          arcana: card_attrs['arcana'],
          suit: card_attrs['suit'],
          description: card_attrs['description'],
          meaning_upright: card_attrs['meaning_upright'],
          meaning_reversed: card_attrs['meaning_reversed'],
          image_url: card_attrs['image_url']
        )
      end
      
      puts "created #{Card.count} cards"
    else
      puts "cards source file not found: #{cards_source}"
    end
    
    # Seed spreads
    spreads_source = "db/seeds/spreads.json"
    
    if File.exist?(spreads_source)
      puts "reading spread data from #{spreads_source}..."
      spread_data = JSON.parse(File.read(spreads_source))
      
      spread_data.each do |spread_attrs|
        puts "creating or updating spread: #{spread_attrs['name']}"
        
        # Find or initialize the spread
        spread = Spread.find_or_initialize_by(name: spread_attrs['name'])
        
        # Update attributes
        spread.update!(
          description: spread_attrs['description'],
          card_count: spread_attrs['card_count'],
          positions: spread_attrs['positions']
        )
      end
      
      puts "created #{Spread.count} spreads"
    else
      puts "spreads source file not found: #{spreads_source}"
    end
    
    puts "database seeding complete"
  end
  
  desc "backup the database to a file"
  task :backup, [:filename] => :environment do |_, args|
    # Default filename uses current timestamp
    filename = args[:filename] || "db/backups/backup_#{Time.now.strftime('%Y%m%d%H%M%S')}.sql"
    
    # Ensure backups directory exists
    FileUtils.mkdir_p(File.dirname(filename))
    
    # Get database config
    config = ActiveRecord::Base.connection_db_config.configuration_hash
    
    puts "backing up database to #{filename}..."
    
    if system("pg_dump -h #{config[:host] || 'localhost'} -U #{config[:username] || 'postgres'} #{config[:database]} > #{filename}")
      puts "database backup completed successfully"
    else
      abort "database backup failed"
    end
  end
  
  desc "restore the database from a backup file"
  task :restore, [:filename] => :environment do |_, args|
    filename = args[:filename] || abort("please specify a backup file to restore from")
    
    unless File.exist?(filename)
      abort "backup file not found: #{filename}"
    end
    
    # Get database config
    config = ActiveRecord::Base.connection_db_config.configuration_hash
    
    puts "restoring database from #{filename}..."
    puts "WARNING: this will overwrite your current database!"
    print "are you sure? [y/N]: "
    confirmation = STDIN.gets.chomp.downcase
    
    if confirmation == "y"
      # Drop and recreate the database
      Rake::Task["db:drop"].invoke
      Rake::Task["db:create"].invoke
      
      # Restore from backup
      if system("psql -h #{config[:host] || 'localhost'} -U #{config[:username] || 'postgres'} #{config[:database]} < #{filename}")
        puts "database restored successfully"
      else
        abort "database restore failed"
      end
    else
      puts "database restore cancelled"
    end
  end
  
  desc "reset the database and seed with fresh data"
  task reset: :environment do
    puts "resetting database..."
    
    # Drop and setup the database
    Rake::Task["db:drop"].invoke
    Rake::Task["db:setup"].invoke
    
    # Seed with custom data
    Rake::Task["data:seed"].invoke
    
    puts "database reset complete"
  end
  
  desc "analyze database for optimization"
  task analyze: :environment do
    puts "analyzing database..."
    
    # Run ANALYZE on all tables
    ActiveRecord::Base.connection.execute("ANALYZE VERBOSE")
    
    # Get table statistics
    stats = ActiveRecord::Base.connection.execute(<<~SQL)
      SELECT
        nspname AS schema,
        relname AS table,
        reltuples AS row_estimate,
        pg_size_pretty(pg_total_relation_size(C.oid)) AS total_size,
        pg_size_pretty(pg_indexes_size(C.oid)) AS index_size,
        pg_size_pretty(pg_relation_size(C.oid)) AS table_size
      FROM pg_class C
      LEFT JOIN pg_namespace N ON (N.oid = C.relnamespace)
      WHERE nspname NOT IN ('pg_catalog', 'information_schema')
        AND C.relkind = 'r'
      ORDER BY pg_total_relation_size(C.oid) DESC;
    SQL
    
    puts "\ndatabase statistics:"
    stats.each do |row|
      puts "#{row['table']}: #{row['row_estimate']} rows, size: #{row['total_size']}"
    end
    
    puts "\ndatabase analysis complete"
  end
end

# Default task for data management
desc "seed database with cards and spreads (alias for data:seed)"
task seed: "data:seed" 