namespace :db do
  namespace :pool do
    desc "Show database connection pool stats"
    task stats: :environment do
      pool = ActiveRecord::Base.connection_pool
      
      stats = {
        size: pool.size,
        active: pool.connections.count(&:in_use?),
        idle: pool.connections.count { |c| !c.in_use? },
        waiting: pool.num_waiting_in_queue,
        usage_percent: ((pool.connections.count(&:in_use?).to_f / pool.size) * 100).round(1)
      }
      
      # Print with nice formatting
      puts "=" * 50
      puts "PostgreSQL Connection Pool Stats:"
      puts "=" * 50
      puts "Pool Size:       #{stats[:size]}"
      puts "Active Conns:    #{stats[:active]}"
      puts "Idle Conns:      #{stats[:idle]}"
      puts "Waiting Threads: #{stats[:waiting]}"
      puts "Usage:           #{stats[:usage_percent]}%"
      puts "=" * 50
    end
    
    desc "Clear all database connections in the pool"
    task clear: :environment do
      puts "Clearing all connections in the PostgreSQL connection pool..."
      
      # Get initial stats
      pool = ActiveRecord::Base.connection_pool
      initial_count = pool.connections.length
      
      # Disconnect all connections
      ActiveRecord::Base.connection_pool.disconnect!
      
      puts "Cleared #{initial_count} connections from the pool"
    end
    
    desc "Verify all database connections in the pool"
    task verify: :environment do
      puts "Verifying all connections in the PostgreSQL connection pool..."
      
      # Get initial stats
      pool = ActiveRecord::Base.connection_pool
      initial_count = pool.connections.length
      
      # Verify all connections
      removed = pool.connections.reject do |conn|
        begin
          result = conn.verify!
          puts "- Connection verified" if result
          result
        rescue => e
          puts "- Connection removed: #{e.message}"
          false
        end
      end.count
      
      if removed > 0
        puts "Removed #{removed} bad connections from pool, #{pool.connections.length}/#{pool.size} remaining"
      else
        puts "All #{initial_count} connections verified successfully"
      end
    end
    
    desc "Optimize database connection pool for Fargate"
    task optimize: :environment do
      original_size = ActiveRecord::Base.connection_pool.size
      
      # Calculate optimal size
      worker_processes = ENV.fetch("WEB_CONCURRENCY") { 2 }.to_i
      threads_per_process = ENV.fetch("RAILS_MAX_THREADS") { 5 }.to_i
      sidekiq_concurrency = ENV.fetch("SIDEKIQ_CONCURRENCY") { 10 }.to_i
      
      base_pool_size = worker_processes * threads_per_process
      total_pool_size = base_pool_size + (sidekiq_concurrency / 2)
      optimal_size = [5, [total_pool_size, 30].min].max
      
      # Update configuration
      config = ActiveRecord::Base.connection_pool.spec.config
      config[:pool] = optimal_size
      
      # Rebuild the connection pool with the new size
      ActiveRecord::Base.connection_pool.disconnect!
      ActiveRecord::Base.establish_connection(config)
      
      puts "PostgreSQL connection pool optimized for Fargate:"
      puts "- Changed pool size from #{original_size} to #{optimal_size}"
      puts "- Optimized based on #{worker_processes} workers with #{threads_per_process} threads each"
      puts "- Sidekiq concurrency set to #{sidekiq_concurrency}"
      
      Rake::Task["db:pool:stats"].invoke
    end
    
    desc "Run database connection health check"
    task healthcheck: :environment do
      puts "Running PostgreSQL connection healthcheck..."
      
      connection_ok = DatabaseHealthcheck.check_connection
      pool_ok = DatabaseHealthcheck.check_pool_health
      
      puts "Database connection: #{connection_ok ? 'OK ✓' : 'ERROR ✗'}"
      puts "Connection pool:     #{pool_ok ? 'OK ✓' : 'WARNING ⚠️'}"
      
      if !connection_ok || !pool_ok
        puts "\nRecommended action:"
        puts "- Run 'rake db:pool:clear' to clear all connections" if !pool_ok
        puts "- Run 'rake db:pool:verify' to verify all connections" if !connection_ok
      end
      
      Rake::Task["db:pool:stats"].invoke
    end
  end
end 