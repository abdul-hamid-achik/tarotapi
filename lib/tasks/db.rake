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
end
