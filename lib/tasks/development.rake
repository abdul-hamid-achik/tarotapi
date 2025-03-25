require "dotenv"
require "semantic_logger"
require_relative "../task_logger"

namespace :dev do
  desc "Set up development environment"
  task setup: :environment do
    puts "Setting up development environment..."
    Rake::Task["dev:docker:rebuild"].invoke
  end

  desc "Check development prerequisites"
  task :check_prerequisites do
    TaskLogger.with_task_logging("dev:check_prerequisites") do
      # Check Ruby version
      required_ruby = File.read(".ruby-version").strip
      actual_ruby = RUBY_VERSION
      unless actual_ruby.start_with?(required_ruby)
        TaskLogger.warn("Ruby version mismatch! Required: #{required_ruby}, Found: #{actual_ruby}")
      end

      # Check Node.js
      unless system("node -v > /dev/null 2>&1")
        TaskLogger.warn("Node.js not found! Please install Node.js")
      end

      # Check PostgreSQL
      unless system("psql --version > /dev/null 2>&1")
        TaskLogger.warn("PostgreSQL not found! Please install PostgreSQL")
      end

      # Check Redis
      unless system("redis-cli ping > /dev/null 2>&1")
        TaskLogger.warn("Redis not running! Please start Redis")
      end
    end
  end

  desc "Install project dependencies"
  task :install_dependencies do
    TaskLogger.with_task_logging("dev:install_dependencies") do
      system("bundle install")
      system("yarn install") if File.exist?("package.json")
    end
  end

  desc "Seed sample data for development"
  task seed_sample_data: :environment do
    TaskLogger.with_task_logging("dev:seed_sample_data") do
      # Add your sample data seeding logic here
      # For example:
      if defined?(User)
        unless User.find_by(email: "admin@example.com")
          User.create!(
            email: "admin@example.com",
            password: "password",
            admin: true
          )
        end
      end
    end
  end

  desc "Clean development environment"
  task clean: :environment do
    TaskLogger.with_task_logging("dev:clean") do
      # Remove temporary files
      FileUtils.rm_rf(Rails.root.join("tmp/cache"))
      FileUtils.rm_rf(Rails.root.join("tmp/pids"))
      FileUtils.rm_rf(Rails.root.join("tmp/sessions"))

      # Clean logs
      FileUtils.rm_rf(Rails.root.join("log/*.log"))

      # Clean test files
      FileUtils.rm_rf(Rails.root.join("coverage"))
      FileUtils.rm_rf(Rails.root.join("spec/reports"))
    end
  end

  desc "Start Docker development environment"
  task :up do
    TaskLogger.with_task_logging("dev:up") do
      # Set development container registry
      ENV["CONTAINER_REGISTRY"] = "ghcr.io/#{ENV['GITHUB_REPOSITORY_OWNER'] || 'abdul-hamid-achik'}/tarotapi"

      system("docker-compose up -d")
    end
  end

  desc "Stop Docker development environment"
  task :down do
    TaskLogger.with_task_logging("dev:down") do
      system("docker-compose down")
    end
  end

  desc "Rebuild Docker development environment"
  task :rebuild do
    TaskLogger.with_task_logging("dev:rebuild") do
      # Set development container registry
      ENV["CONTAINER_REGISTRY"] = "ghcr.io/#{ENV['GITHUB_REPOSITORY_OWNER'] || 'abdul-hamid-achik'}/tarotapi"

      system("docker-compose build --no-cache")
    end
  end

  namespace :docker do
    desc "Rebuild Docker containers with fresh gem installation"
    task :rebuild do
      puts "Rebuilding Docker containers..."
      system "docker-compose down --volumes"
      system "docker-compose build --no-cache api"
      puts "Starting containers..."
      system "docker-compose up -d"
    end

    desc "Fix gem installation inside container"
    task :fix_gems do
      puts "Fixing gem installation inside container..."
      system "docker-compose exec api bundle config set --local force_ruby_platform true"
      system "docker-compose exec api bundle install --jobs 4 --retry 3 --full-index"
    end

    desc "Enter a Rails console inside the container"
    task :console do
      system "docker-compose exec api bundle exec rails console"
    end

    desc "Show container logs"
    task :logs do
      system "docker-compose logs -f api"
    end

    desc "Run a bash shell inside the container"
    task :bash do
      system "docker-compose exec api bash"
    end

    desc "Check container and dependencies health"
    task :health do
      puts "Checking container health..."
      system "docker-compose ps"
      puts "\nChecking database connection..."
      system "docker-compose exec api bundle exec rails db:version"
      puts "\nChecking Redis connection..."
      system "docker-compose exec api bundle exec rails runner 'puts Redis.new.ping'"
    end
  end
end

namespace :test do
  desc "Kill all connections to the test database"
  task kill_connections: :environment do
    TaskLogger.with_task_logging("test:kill_connections") do
      db_config = ActiveRecord::Base.configurations.configs_for(env_name: Rails.env == "test" ? "test" : "development")
      db_name = ENV["DATABASE_NAME"] || db_config.database

      # This query terminates all connections to the specified database
      # Using a stronger approach with pg_terminate_backend and setting_for_user
      sql = <<-SQL
        SELECT pg_terminate_backend(pg_stat_activity.pid)
        FROM pg_stat_activity
        WHERE pg_stat_activity.datname = '#{db_name}'
        AND pid <> pg_backend_pid();
      SQL

      # Execute the query directly to avoid the active record connection pooling
      begin
        ActiveRecord::Base.connection.execute(sql)
        TaskLogger.info("All connections to #{db_name} have been terminated")
      rescue => e
        TaskLogger.warn("Error terminating connections: #{e.message}")
        # Try a fallback approach
        system("ps -ef | grep postgres | grep -v grep | awk '{print $2}' | xargs -I{} kill -9 {}")
        TaskLogger.info("Used fallback approach for terminating connections")
      end

      # Add a small delay to ensure connections are fully closed
      sleep 1
    end
  end

  desc "Run all tests"
  task :all do
    TaskLogger.with_task_logging("test:all") do
      # Set Rails environment to test
      ENV["RAILS_ENV"] = "test"

      # Kill all existing connections
      begin
        Rake::Task["test:kill_connections"].invoke
      rescue => e
        TaskLogger.warn("Failed to kill connections: #{e.message}")
      end

      # Prepare test database safely
      begin
        Rake::Task["db:test:prepare"].invoke
      rescue => e
        TaskLogger.warn("Failed to prepare database: #{e.message}")
      end

      # Run the tests
      [ "test:unit", "test:integration", "test:system" ].each do |task|
        Rake::Task[task].invoke
        # Re-enable the task for the next run
        Rake::Task[task].reenable
      end
    end
  end

  desc "Prepare test environment"
  task :prepare do
    TaskLogger.with_task_logging("test:prepare") do
      ENV["RAILS_ENV"] = "test"

      # Ensure test database is ready
      Rake::Task["db:test:prepare"].invoke

      # Clear test logs
      FileUtils.rm_f(Rails.root.join("log/test.log"))
    end
  end

  desc "Run unit tests"
  task :unit do
    TaskLogger.with_task_logging("test:unit") do
      ENV["RAILS_ENV"] = "test"
      system("bundle exec rspec spec/models spec/services spec/helpers")
    end
  end

  desc "Run integration tests"
  task :integration do
    TaskLogger.with_task_logging("test:integration") do
      ENV["RAILS_ENV"] = "test"
      system("bundle exec rspec spec/requests spec/controllers")
    end
  end

  desc "Run system tests"
  task :system do
    TaskLogger.with_task_logging("test:system") do
      ENV["RAILS_ENV"] = "test"
      system("bundle exec rspec spec/system")
    end
  end

  namespace :coverage do
    desc "Generate test coverage report"
    task :report do
      TaskLogger.with_task_logging("test:coverage:report") do
        ENV["COVERAGE"] = "true"
        Rake::Task["test:all"].invoke
      end
    end
  end

  desc "Run tests without recreating the database"
  task :run do
    TaskLogger.with_task_logging("test:run") do
      ENV["RAILS_ENV"] = "test"

      # Run the tests
      [ "test:unit", "test:integration", "test:system" ].each do |task|
        Rake::Task[task].invoke
        # Re-enable the task for the next run
        Rake::Task[task].reenable
      end
    end
  end
end

namespace :ci do
  desc "Run all CI tasks"
  task all: :environment do
    ENV["DISABLE_RAILS_SEMANTIC_LOGGER"] = "true"

    # Explicitly close database connections before running tests
    Rake::Task["db:disconnect"].invoke

    # Run tasks in order: lint first, security second, tests last
    %w[ci:lint ci:security ci:test].each do |task|
      Rake::Task[task].invoke
    end

    ENV["DISABLE_RAILS_SEMANTIC_LOGGER"] = nil
  end

  desc "Run linting checks"
  task lint: :environment do
    TaskLogger.with_task_logging("ci:lint") do
      system("bundle exec rubocop -a")
    end
  end

  desc "Run security checks"
  task security: :environment do
    TaskLogger.with_task_logging("ci:security") do
      # Check for vulnerable dependencies
      system("bundle exec bundle-audit update && bundle exec bundle-audit check")

      # Run Brakeman for security analysis
      system("bundle exec brakeman --no-pager -q")
    end
  end

  desc "Run all tests"
  task test: :environment do
    TaskLogger.with_task_logging("ci:test") do
      # Configure test environment
      ENV["RAILS_ENV"] = "test"
      ENV["DISABLE_RAILS_SEMANTIC_LOGGER"] = "true"

      # Ensure database is ready with hard reset to completely clear connections
      Rake::Task["db:test:hard_reset"].invoke

      # Run the tests
      test_success = system("bundle exec rspec")

      # Clean up database connections
      Rake::Task["db:test:force_disconnect"].invoke

      ENV["DISABLE_RAILS_SEMANTIC_LOGGER"] = nil

      # Exit with the same status as the tests
      exit(1) unless test_success
    end
  end

  namespace :docker do
    desc "Build and test in Docker"
    task :test do
      TaskLogger.with_task_logging("ci:docker:test") do
        system(<<~SHELL)
          docker-compose -f docker-compose.test.yml build
          docker-compose -f docker-compose.test.yml run --rm web bundle exec rake test:all
        SHELL
      end
    end
  end
end

namespace :db do
  desc "Close all database connections"
  task disconnect: :environment do
    puts "Closing all database connections..."

    config = ActiveRecord::Base.connection_db_config.configuration_hash
    db_name = config[:database]

    # Close connections to the current database
    ActiveRecord::Base.connection.execute(<<~SQL)
      SELECT pg_terminate_backend(pg_stat_activity.pid)
      FROM pg_stat_activity
      WHERE pg_stat_activity.datname = '#{db_name}'
      AND pid <> pg_backend_pid();
    SQL

    # Also close connections to the test database
    if db_name != "#{db_name.gsub(/_development$/, '')}_test"
      test_db_name = "#{db_name.gsub(/_development$/, '')}_test"
      begin
        ActiveRecord::Base.connection.execute(<<~SQL)
          SELECT pg_terminate_backend(pg_stat_activity.pid)
          FROM pg_stat_activity
          WHERE pg_stat_activity.datname = '#{test_db_name}'
          AND pid <> pg_backend_pid();
        SQL
      rescue => e
        # Ignore errors if test database doesn't exist yet
        puts "Note: Could not disconnect from test database: #{e.message}"
      end
    end

    puts "Database connections closed."
  end
end

# Add Docker-specific Rake tasks
namespace :docker do
  desc "Build development Docker image"
  task :build do
    TaskLogger.with_task_logging("docker:build") do
      # Set development container registry
      ENV["CONTAINER_REGISTRY"] = "ghcr.io/#{ENV['GITHUB_REPOSITORY_OWNER'] || 'abdul-hamid-achik'}/tarotapi"

      system("docker-compose build")
    end
  end

  desc "Push development Docker image to GitHub Container Registry"
  task :push do
    TaskLogger.with_task_logging("docker:push") do
      # Set development container registry
      registry = ENV["CONTAINER_REGISTRY"] || "ghcr.io/#{ENV['GITHUB_REPOSITORY_OWNER'] || 'abdul-hamid-achik'}/tarotapi"

      # Tag and push the image
      system("docker tag tarotapi:latest #{registry}:development")
      system("docker push #{registry}:development")
    end
  end
end
