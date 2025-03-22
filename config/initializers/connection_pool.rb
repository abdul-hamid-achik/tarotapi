# Advanced connection pool management for Tarot API
# Optimized for AWS Fargate with a single database source

# Calculate optimal pool size based on Fargate task configuration
# More conservative since we're using a single database source
def calculate_pool_size
  # Get the number of worker processes/threads from Puma or another server
  worker_processes = ENV.fetch("WEB_CONCURRENCY") { 2 }.to_i
  threads_per_process = ENV.fetch("RAILS_MAX_THREADS") { 5 }.to_i
  
  # For sidekiq, we need to account for its concurrency
  sidekiq_concurrency = ENV.fetch("SIDEKIQ_CONCURRENCY") { 10 }.to_i
  
  # Calculate base pool size
  base_pool_size = worker_processes * threads_per_process
  
  # For single database source, we need to be more conservative
  # Add a smaller buffer for background jobs to avoid overloading the DB
  total_pool_size = base_pool_size + (sidekiq_concurrency / 2)
  
  # Set minimum and more conservative maximum limits
  # This prevents connection saturation on the single database
  [5, [total_pool_size, 30].min].max
end

# Configure ActiveRecord connection pool settings
ActiveSupport.on_load(:active_record) do
  # Only apply in development or test if not explicitly set in database.yml
  unless Rails.env.production? || ENV["RAILS_MAX_THREADS"].present?
    config = ActiveRecord::Base.configurations.configs_for(env_name: Rails.env).first
    config.pool = calculate_pool_size if config.respond_to?(:pool=)
  end
  
  # Add connection pool health check middleware to the Rails app
  # This helps identify and fix connection pool issues
  Rails.application.config.middleware.insert_before(0, Rack::Runtime) do
    Class.new do
      def initialize(app)
        @app = app
      end
      
      def call(env)
        # Check connection pool status before processing request
        begin
          pool_stats = {
            pool_size: ActiveRecord::Base.connection_pool.size,
            connections: ActiveRecord::Base.connection_pool.connections.length,
            busy: ActiveRecord::Base.connection_pool.stat[:busy],
            dead: ActiveRecord::Base.connection_pool.stat[:dead],
            idle: ActiveRecord::Base.connection_pool.stat[:idle],
            waiting: ActiveRecord::Base.connection_pool.stat[:waiting]
          }
          
          # Lower the threshold to 70% for warning since we have a single DB source
          if pool_stats[:busy] >= pool_stats[:pool_size] * 0.7
            Rails.logger.warn "Connection pool nearly full ⚠️: #{pool_stats.inspect}"
          end
          
          # Log if we have dead connections
          if pool_stats[:dead] > 0
            Rails.logger.warn "Dead database connections detected ⚠️: #{pool_stats[:dead]}"
          end
          
          # Store stats in request env for debugging if needed
          env['tarot_api.db_pool_stats'] = pool_stats
        rescue => e
          Rails.logger.error "Error checking connection pool: #{e.message}"
        end
        
        @app.call(env)
      ensure
        # Ensure connections are returned to the pool after request
        # This helps prevent connection leaks
        ActiveRecord::Base.clear_active_connections!
      end
    end
  end
  
  # Set up after-fork handler for Puma, Unicorn, etc.
  # This reconnects to the database after workers are forked
  ActiveRecord::Base.connection_pool.disconnect! if defined?(ActiveRecord)
  
  # Automatically clean up idle connections more frequently
  # This is important for a single database source to prevent connection saturation
  if Rails.env.production?
    # Schedule more frequent connection pool reaping
    Thread.new do
      loop do
        begin
          sleep 180 # 3 minutes instead of 5 for more aggressive cleanup
          ActiveRecord::Base.connection_pool.reap
          ActiveRecord::Base.connection_pool.flush!
          GC.start
        rescue => e
          Rails.logger.error "Connection pool maintenance error: #{e.message}"
        end
      end
    end
  end
end 