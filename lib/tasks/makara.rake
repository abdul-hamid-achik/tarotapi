namespace :makara do
  desc "Test and validate Makara replica setup"
  task validate: :environment do
    puts "== Validating Makara PostgreSQL Replica Setup =="
    puts "  Environment: #{Rails.env}"
    
    # Check if Makara is enabled for this environment
    if ENV["DB_REPLICA_ENABLED"] != "true"
      puts "✗ Makara is not enabled (DB_REPLICA_ENABLED is not 'true')"
      puts "  To enable Makara, set DB_REPLICA_ENABLED=true"
      exit 1
    end
    
    # Check if current database config is using Makara
    db_config = ActiveRecord::Base.connection_db_config.configuration_hash
    
    if db_config[:adapter] != 'makara_postgresql'
      puts "✗ Database is not using Makara adapter (using #{db_config[:adapter]} instead)"
      puts "  Check your database.yml configuration."
      exit 1
    end
    
    puts "✓ Database is using Makara adapter"
    
    # Get Makara connection configuration
    makara_config = db_config[:makara]
    
    unless makara_config && makara_config[:connections].is_a?(Array)
      puts "✗ Makara configuration not found or invalid"
      puts "  Check your database.yml configuration."
      exit 1
    end
    
    # Check each connection
    makara_config[:connections].each do |conn|
      role = conn[:role] || conn["role"]
      name = conn[:name] || conn["name"]
      
      puts "\n== Testing #{role} connection (#{name}) =="
      
      begin
        # Try to create a connection to this specific node
        config = conn.symbolize_keys.except(:role, :name)
        config[:adapter] = 'postgresql'
        
        puts "  Connecting to #{config[:host]}:#{config[:port]} as #{config[:username]}"
        connection = ActiveRecord::Base.postgresql_connection(config)
        
        # Test connection
        version = connection.select_value("SELECT version()")
        puts "✓ Connected to #{role} database: #{version}"
        
        # Additional info
        connection_count = connection.select_value("SELECT count(*) FROM pg_stat_activity WHERE datname = '#{config[:database]}'")
        puts "  Current connections: #{connection_count}"
        
        # Close the test connection
        connection.disconnect!
      rescue => e
        puts "✗ Failed to connect to #{role} database: #{e.message}"
        puts "  Check your connection settings and ensure the database is reachable."
      end
    end
    
    puts "\n== Testing Makara routing =="
    
    # Test if reads are being routed to replicas
    begin
      # Force next read to go to replica
      Makara::Context.set_current(Makara::Context.generate)
      
      # Execute a read query and see where it goes
      start_time = Time.now
      result = ActiveRecord::Base.connection.select_value("SELECT current_setting('session.role')")
      end_time = Time.now
      
      puts "  Query execution time: #{((end_time - start_time) * 1000).round(2)}ms"
      puts "  Session role: #{result || 'Not set'}"
      
      # For PostgreSQL databases with replication roles configured, this would show 'replica' or similar
      # For standard setups, we can't easily detect if it used the replica, so we warn about that
      puts "  Note: To confirm replica routing, configure session.role differently on primary and replica."
    rescue => e
      puts "✗ Failed to test query routing: #{e.message}"
    end
    
    puts "\n== Makara Configuration Summary =="
    puts "  Sticky sessions: #{makara_config[:sticky] ? 'Enabled' : 'Disabled'}"
    puts "  Blacklist duration: #{makara_config[:blacklist_duration] || 'Default'} seconds"
    puts "  Primary connections: #{makara_config[:connections].count { |c| (c[:role] || c['role']) == 'primary' }}"
    puts "  Replica connections: #{makara_config[:connections].count { |c| (c[:role] || c['role']) == 'replica' }}"
    puts ""
    puts "== Validation Complete =="
  end
  
  desc "Simulate a load test on the database with Makara"
  task load_test: :environment do
    puts "== Makara Load Test =="
    puts "  Running 100 read queries and 10 write queries to test balancing"
    
    read_times = []
    write_times = []
    
    # Perform writes (should go to primary)
    10.times do |i|
      Makara::Context.clear_current
      start_time = Time.now
      begin
        # Use a transaction to force primary use
        ActiveRecord::Base.transaction do
          # Just do a simple read within transaction to avoid actual writes
          ActiveRecord::Base.connection.select_value("SELECT 1")
        end
        write_times << (Time.now - start_time)
        print "W"
      rescue => e
        puts "\nWrite error: #{e.message}"
      end
    end
    
    # Perform reads (should go to replicas when available)
    100.times do |i|
      # Generate a new context for each read to avoid sticking
      Makara::Context.set_current(Makara::Context.generate)
      
      start_time = Time.now
      begin
        ActiveRecord::Base.connection.select_value("SELECT 1")
        read_times << (Time.now - start_time)
        print "R"
      rescue => e
        puts "\nRead error: #{e.message}"
      end
      
      # Small pause between requests
      sleep 0.01
    end
    
    puts "\n\n== Results =="
    if read_times.any?
      avg_read = (read_times.sum / read_times.size) * 1000
      puts "  Reads: #{read_times.size} queries, avg #{avg_read.round(2)}ms"
    end
    
    if write_times.any?
      avg_write = (write_times.sum / write_times.size) * 1000
      puts "  Writes: #{write_times.size} queries, avg #{avg_write.round(2)}ms"
    end
    
    puts "\nLoad test complete"
  end
  
  desc "Show current Makara status and configuration"
  task status: :environment do
    puts "== Makara Status =="
    
    # Check if Makara is enabled
    if ENV["DB_REPLICA_ENABLED"] != "true"
      puts "Makara is not enabled (DB_REPLICA_ENABLED != true)"
      exit
    end
    
    # Check connection configuration
    db_config = ActiveRecord::Base.connection_db_config.configuration_hash
    
    if db_config[:adapter] != 'makara_postgresql'
      puts "Database is not using Makara adapter (using #{db_config[:adapter]} instead)"
      exit
    end
    
    puts "Makara is active with PostgreSQL"
    
    # Get connection counts if possible
    begin
      puts "\n== Database Connections =="
      
      primary_count = ActiveRecord::Base.connection.select_value(
        "SELECT count(*) FROM pg_stat_activity WHERE application_name LIKE '%primary%'"
      )
      
      replica_count = ActiveRecord::Base.connection.select_value(
        "SELECT count(*) FROM pg_stat_activity WHERE application_name LIKE '%replica%'"
      )
      
      puts "  Primary connections: #{primary_count || 'Unknown'}"
      puts "  Replica connections: #{replica_count || 'Unknown'}"
    rescue => e
      puts "Could not determine connection counts: #{e.message}"
    end
    
    # Show Makara proxy details if accessible
    if ActiveRecord::Base.connection.respond_to?(:proxy)
      proxy = ActiveRecord::Base.connection.proxy
      
      if proxy.respond_to?(:primary_pool) && proxy.respond_to?(:replica_pool)
        puts "\n== Makara Connection Pools =="
        
        puts "  Primary pool:"
        puts "    Connections: #{proxy.primary_pool.connections.size}"
        puts "    Blacklisted: #{proxy.primary_pool.blacklisted?}"
        
        puts "  Replica pool:"
        puts "    Connections: #{proxy.replica_pool.connections.size}"
        puts "    Blacklisted: #{proxy.replica_pool.blacklisted?}"
      end
    end
  end
end 