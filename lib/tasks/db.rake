namespace :db do
  # Helper method to detect if running inside Docker
  def inside_docker?
    File.exist?("/.dockerenv")
  end

  # Helper method to get the docker prefix for commands
  def docker_prefix(service)
    inside_docker? ? "" : "docker compose exec #{service} "
  end

  desc "backup database to file"
  task :backup, [ :filename ] => :environment do |_, args|
    require "date"

    # Default filename with timestamp if not provided
    filename = args[:filename] || "db_backup_#{Date.today.strftime('%Y%m%d')}.dump"

    config = ActiveRecord::Base.connection_db_config.configuration_hash

    puts "backing up database to #{filename}..."

    # Build connection arguments
    conn_args = []
    conn_args << "-h #{config[:host]}" if config[:host].present?
    conn_args << "-p #{config[:port]}" if config[:port].present?
    conn_args << "-U #{config[:username]}" if config[:username].present?
    conn_args = conn_args.join(" ")

    # Execute pg_dump
    cmd = "#{docker_prefix('postgres')}pg_dump #{conn_args} #{config[:database]} > #{filename}"

    if system(cmd)
      puts "database backup complete: #{filename}"
    else
      abort "database backup failed"
    end
  end

  desc "restore database from backup file"
  task :restore, [ :filename ] => :environment do |_, args|
    abort "filename required" unless args[:filename]
    abort "file not found: #{args[:filename]}" unless File.exist?(args[:filename])

    config = ActiveRecord::Base.connection_db_config.configuration_hash

    puts "restoring database from #{args[:filename]}..."

    # Build connection arguments
    conn_args = []
    conn_args << "-h #{config[:host]}" if config[:host].present?
    conn_args << "-p #{config[:port]}" if config[:port].present?
    conn_args << "-U #{config[:username]}" if config[:username].present?
    conn_args = conn_args.join(" ")

    # Execute psql
    cmd = "#{docker_prefix('postgres')}psql #{conn_args} -d #{config[:database]} < #{args[:filename]}"

    if system(cmd)
      puts "database restore complete"
    else
      abort "database restore failed"
    end
  end

  desc "analyze database for query optimization"
  task analyze: :environment do
    config = ActiveRecord::Base.connection_db_config.configuration_hash

    puts "analyzing database..."

    # Build connection arguments
    conn_args = []
    conn_args << "-h #{config[:host]}" if config[:host].present?
    conn_args << "-p #{config[:port]}" if config[:port].present?
    conn_args << "-U #{config[:username]}" if config[:username].present?
    conn_args = conn_args.join(" ")

    # Execute ANALYZE
    cmd = "#{docker_prefix('postgres')}psql #{conn_args} -d #{config[:database]} -c \"ANALYZE VERBOSE;\""

    if system(cmd)
      puts "database analysis complete"
    else
      abort "database analysis failed"
    end
  end

  desc "check if database exists"
  task exists: :environment do
    begin
      ActiveRecord::Base.connection
      puts "database exists"
      exit 0
    rescue ActiveRecord::NoDatabaseError
      puts "database does not exist"
      exit 1
    end
  end

  namespace :update do
    desc "Update card readings table with new reference columns"
    task card_readings: :environment do
      puts "Starting update of card_readings table..."
      
      if ActiveRecord::Base.connection.table_exists?("card_readings")
        # Check for old columns
        has_tarot_card_id = ActiveRecord::Base.connection.column_exists?(:card_readings, :tarot_card_id)
        has_reading_session_id = ActiveRecord::Base.connection.column_exists?(:card_readings, :reading_session_id)
        
        # Check for new columns
        has_card_id = ActiveRecord::Base.connection.column_exists?(:card_readings, :card_id)
        has_reading_id = ActiveRecord::Base.connection.column_exists?(:card_readings, :reading_id)
        
        if !has_card_id && has_tarot_card_id
          puts "Adding card_id column to card_readings..."
          ActiveRecord::Base.connection.add_reference :card_readings, :card, foreign_key: true, index: true
          
          puts "Copying data from tarot_card_id to card_id..."
          ActiveRecord::Base.connection.execute(<<-SQL)
            UPDATE card_readings 
            SET card_id = tarot_card_id
            WHERE card_id IS NULL AND tarot_card_id IS NOT NULL
          SQL
        end
        
        if !has_reading_id && has_reading_session_id
          puts "Adding reading_id column to card_readings..."
          ActiveRecord::Base.connection.add_reference :card_readings, :reading, foreign_key: true, index: true
          
          puts "Copying data from reading_session_id to reading_id..."
          ActiveRecord::Base.connection.execute(<<-SQL)
            UPDATE card_readings 
            SET reading_id = reading_session_id
            WHERE reading_id IS NULL AND reading_session_id IS NOT NULL
          SQL
        end
        
        # Remove old columns if they exist
        if has_tarot_card_id && has_card_id
          puts "Removing tarot_card_id column..."
          ActiveRecord::Base.connection.remove_reference :card_readings, :tarot_card, foreign_key: true, index: true
        end
        
        if has_reading_session_id && has_reading_id
          puts "Removing reading_session_id column..."
          ActiveRecord::Base.connection.remove_reference :card_readings, :reading_session, foreign_key: true, index: true
        end
        
        puts "Card readings table updated successfully!"
      else
        puts "Card readings table does not exist. Skipping update."
      end
    end
  end
end
