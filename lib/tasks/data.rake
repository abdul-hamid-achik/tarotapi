# Load the TaskLogger module
require_relative '../task_logger'

namespace :data do
  desc "seed the database with tarot cards and spreads"
  task seed: :environment do
    TaskLogger.with_task_logging("data:seed") do
      # Get card data source
      cards_source = "db/seeds/cards.json"

      if File.exist?(cards_source)
        # Parse the card data
        TaskLogger.info("Reading card data", source: cards_source)
        card_data = JSON.parse(File.read(cards_source))

        # Create the cards
        card_data.each do |card_attrs|
          TaskLogger.debug("Creating or updating card", name: card_attrs['name'])

          # Find or initialize the card
          card = Card.find_or_initialize_by(name: card_attrs["name"])

          # Update attributes
          card.update!(
            number: card_attrs["number"],
            arcana: card_attrs["arcana"],
            suit: card_attrs["suit"],
            description: card_attrs["description"],
            meaning_upright: card_attrs["meaning_upright"],
            meaning_reversed: card_attrs["meaning_reversed"],
            image_url: card_attrs["image_url"]
          )
        end

        TaskLogger.info("Created cards", count: Card.count)
      else
        TaskLogger.error("Cards source file not found", path: cards_source)
      end

      # Seed spreads
      spreads_source = "db/seeds/spreads.json"

      if File.exist?(spreads_source)
        TaskLogger.info("Reading spread data", source: spreads_source)
        spread_data = JSON.parse(File.read(spreads_source))

        spread_data.each do |spread_attrs|
          TaskLogger.debug("Creating or updating spread", name: spread_attrs['name'])

          # Find or initialize the spread
          spread = Spread.find_or_initialize_by(name: spread_attrs["name"])

          # Update attributes
          spread.update!(
            description: spread_attrs["description"],
            card_count: spread_attrs["card_count"],
            positions: spread_attrs["positions"]
          )
        end

        TaskLogger.info("Created spreads", count: Spread.count)
      else
        TaskLogger.error("Spreads source file not found", path: spreads_source)
      end

      TaskLogger.info("Database seeding complete")
    end
  end

  desc "backup the database to a file"
  task :backup, [ :filename ] => :environment do |_, args|
    TaskLogger.with_task_logging("data:backup") do
      # Default filename uses current timestamp
      filename = args[:filename] || "db/backups/backup_#{Time.now.strftime('%Y%m%d%H%M%S')}.sql"

      # Ensure backups directory exists
      FileUtils.mkdir_p(File.dirname(filename))

      # Get database config
      config = ActiveRecord::Base.connection_db_config.configuration_hash

      TaskLogger.info("Backing up database", target: filename)

      if system("pg_dump -h #{config[:host] || 'localhost'} -U #{config[:username] || 'postgres'} #{config[:database]} > #{filename}")
        TaskLogger.info("Database backup completed successfully")
      else
        TaskLogger.error("Database backup failed")
        abort
      end
    end
  end

  desc "restore the database from a backup file"
  task :restore, [ :filename ] => :environment do |_, args|
    TaskLogger.with_task_logging("data:restore") do
      filename = args[:filename] || TaskLogger.error("Please specify a backup file to restore from") && abort

      unless File.exist?(filename)
        TaskLogger.error("Backup file not found", path: filename)
        abort
      end

      # Get database config
      config = ActiveRecord::Base.connection_db_config.configuration_hash

      TaskLogger.warn("Restoring database from backup", source: filename)
      TaskLogger.warn("WARNING: This will overwrite your current database!")
      print "Are you sure? [y/N]: "
      confirmation = STDIN.gets.chomp.downcase

      if confirmation == "y"
        # Drop and recreate the database
        Rake::Task["db:drop"].invoke
        Rake::Task["db:create"].invoke

        # Restore from backup
        if system("psql -h #{config[:host] || 'localhost'} -U #{config[:username] || 'postgres'} #{config[:database]} < #{filename}")
          TaskLogger.info("Database restored successfully")
        else
          TaskLogger.error("Database restore failed")
          abort
        end
      else
        TaskLogger.info("Database restore cancelled")
      end
    end
  end

  desc "reset the database and seed with fresh data"
  task reset: :environment do
    TaskLogger.with_task_logging("data:reset") do
      TaskLogger.info("Resetting database...")

      # Drop and setup the database
      Rake::Task["db:drop"].invoke
      Rake::Task["db:setup"].invoke

      # Seed with custom data
      Rake::Task["data:seed"].invoke

      TaskLogger.info("Database reset complete")
    end
  end

  desc "analyze database for optimization"
  task analyze: :environment do
    TaskLogger.with_task_logging("data:analyze") do
      TaskLogger.info("Analyzing database...")

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

      stats_data = stats.map { |row| { table: row['table'], rows: row['row_estimate'], size: row['total_size'] } }
      TaskLogger.info("Database statistics", tables: stats_data)

      TaskLogger.info("Database analysis complete")
    end
  end
end

# Default task for data management
desc "seed database with cards and spreads (alias for data:seed)"
task seed: "data:seed"
