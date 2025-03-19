namespace :app do
  # Helper method to detect if running inside Docker
  def inside_docker?
    File.exist?("/.dockerenv")
  end

  desc "setup the application (install dependencies, setup database)"
  task setup: :environment do
    puts "setting up application..."

    # Run the same setup regardless of Docker status
    system("bundle install") || abort("bundle install failed")
    Rake::Task["db:setup"].invoke

    puts "application setup complete"
  end

  desc "reset the application (drop database, recreate, migrate, seed)"
  task reset: :environment do
    puts "resetting application..."

    # No need to branch based on Docker - the operations are the same
    Rake::Task["db:drop"].invoke
    Rake::Task["db:setup"].invoke

    puts "application reset complete"
  end

  desc "health check for application"
  task health: :environment do
    errors = []

    # Check database connection
    begin
      ActiveRecord::Base.connection
      puts "database: connected"
    rescue => e
      errors << "database connection failed: #{e.message}"
    end

    # Check redis connection if used
    if defined?(Redis)
      begin
        redis = Redis.new(url: ENV.fetch("REDIS_URL") { "redis://localhost:6379/1" })
        redis.ping
        puts "redis: connected"
      rescue => e
        errors << "redis connection failed: #{e.message}"
      end
    end

    # Check AWS S3 connection if used
    if defined?(Aws::S3::Client)
      begin
        s3 = Aws::S3::Client.new
        s3.list_buckets
        puts "s3: connected"
      rescue => e
        errors << "s3 connection failed: #{e.message}"
      end
    end

    if errors.any?
      puts "health check failed:"
      errors.each { |error| puts "- #{error}" }
      exit 1
    else
      puts "health check passed"
    end
  end
end
