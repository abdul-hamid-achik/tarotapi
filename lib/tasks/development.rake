require "dotenv"
require "semantic_logger"
require_relative "../task_logger"

namespace :dev do
  desc "Set up development environment"
  task setup: :environment do
    TaskLogger.info("Setting up development environment...")

    Rake::Task["dev:check_prerequisites"].invoke
    Rake::Task["dev:install_dependencies"].invoke
    Rake::Task["db:setup"].invoke
    Rake::Task["dev:seed_sample_data"].invoke

    TaskLogger.info("Development environment setup completed!")
  end

  desc "Check development prerequisites"
  task :check_prerequisites do
    TaskLogger.info("Checking development prerequisites...")

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

  desc "Install project dependencies"
  task :install_dependencies do
    TaskLogger.info("Installing project dependencies...")

    system("bundle install")
    system("yarn install") if File.exist?("package.json")
  end

  desc "Seed sample data for development"
  task seed_sample_data: :environment do
    TaskLogger.info("Seeding sample data...")

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

    TaskLogger.info("Sample data seeded successfully!")
  end

  desc "Clean development environment"
  task clean: :environment do
    TaskLogger.info("Cleaning development environment...")

    # Remove temporary files
    FileUtils.rm_rf(Rails.root.join("tmp/cache"))
    FileUtils.rm_rf(Rails.root.join("tmp/pids"))
    FileUtils.rm_rf(Rails.root.join("tmp/sessions"))

    # Clean logs
    FileUtils.rm_rf(Rails.root.join("log/*.log"))

    # Clean test files
    FileUtils.rm_rf(Rails.root.join("coverage"))
    FileUtils.rm_rf(Rails.root.join("spec/reports"))

    TaskLogger.info("Development environment cleaned!")
  end
end

namespace :test do
  desc "Kill all connections to the test database"
  task kill_connections: :environment do
    db_name = ActiveRecord::Base.connection_db_config.database
    TaskLogger.info("Killing all connections to #{db_name}...")

    # This query terminates all connections to the specified database
    sql = <<-SQL
      SELECT pg_terminate_backend(pg_stat_activity.pid)
      FROM pg_stat_activity
      WHERE pg_stat_activity.datname = '#{db_name}'
      AND pid <> pg_backend_pid();
    SQL

    ActiveRecord::Base.connection.execute(sql)
    TaskLogger.info("All connections to #{db_name} have been terminated")
  end

  desc "Run all tests"
  task :all do
    # Set Rails environment to test
    ENV["RAILS_ENV"] = "test"

    # Kill all existing connections
    TaskLogger.info("Killing all connections to test database...")
    begin
      Rake::Task["test:kill_connections"].invoke
    rescue => e
      TaskLogger.warn("Failed to kill connections: #{e.message}")
    end

    # Prepare test database safely
    TaskLogger.info("Preparing test database...")
    begin
      Rake::Task["db:test:prepare"].invoke
    rescue => e
      TaskLogger.warn("Failed to prepare database: #{e.message}")
    end

    TaskLogger.info("Test database preparation complete!")

    TaskLogger.info("Running all tests...")

    # Run the tests
    [ "test:unit", "test:integration", "test:system" ].each do |task|
      Rake::Task[task].invoke
      # Re-enable the task for the next run
      Rake::Task[task].reenable
    end

    TaskLogger.info("All tests completed!")
  end

  desc "Prepare test environment"
  task :prepare do
    TaskLogger.info("Preparing test environment...")

    ENV["RAILS_ENV"] = "test"

    # Ensure test database is ready
    Rake::Task["db:test:prepare"].invoke

    # Clear test logs
    FileUtils.rm_f(Rails.root.join("log/test.log"))
  end

  desc "Run unit tests"
  task :unit do
    TaskLogger.info("Running unit tests...")
    ENV["RAILS_ENV"] = "test"
    system("bundle exec rspec spec/models spec/services spec/helpers")
  end

  desc "Run integration tests"
  task :integration do
    TaskLogger.info("Running integration tests...")
    ENV["RAILS_ENV"] = "test"
    system("bundle exec rspec spec/requests spec/controllers")
  end

  desc "Run system tests"
  task :system do
    TaskLogger.info("Running system tests...")
    ENV["RAILS_ENV"] = "test"
    system("bundle exec rspec spec/system")
  end

  namespace :coverage do
    desc "Generate test coverage report"
    task :report do
      TaskLogger.info("Generating test coverage report...")

      ENV["COVERAGE"] = "true"
      Rake::Task["test:all"].invoke

      TaskLogger.info("Coverage report generated in coverage/index.html")
    end
  end
end

namespace :ci do
  desc "Run continuous integration checks"
  task :all do
    TaskLogger.info("Running CI checks...")

    Rake::Task["ci:lint"].invoke
    Rake::Task["ci:security"].invoke
    # Re-enable tests now that we have Docker services running
    Rake::Task["test:all"].invoke

    TaskLogger.info("CI checks completed!")
  end

  desc "Run linting checks"
  task :lint do
    TaskLogger.info("Running linting checks...")

    # Run RuboCop
    system("bundle exec rubocop")

    # Run ESLint if JavaScript files exist
    if File.exist?("package.json")
      system("yarn lint")
    end
  end

  desc "Run security checks"
  task :security do
    TaskLogger.info("Running security checks...")

    # Check for vulnerable dependencies
    system("bundle exec bundle audit check --update")

    # Run Brakeman for security analysis with no pager and colored output
    system("bundle exec brakeman -q -w2 --no-pager --color")
  end

  namespace :docker do
    desc "Build and test in Docker"
    task :test do
      TaskLogger.info("Running tests in Docker...")

      system(<<~SHELL)
        docker-compose -f docker-compose.test.yml build
        docker-compose -f docker-compose.test.yml run --rm web bundle exec rake test:all
      SHELL
    end
  end
end
