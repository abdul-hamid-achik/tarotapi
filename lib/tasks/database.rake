require "dotenv"
require "semantic_logger"
require_relative "../task_logger"

namespace :db do
  desc "Check database configuration for all environments"
  task check_config: :environment do
    TaskLogger.info("\nChecking database configuration...")

    %w[development test production].each do |env|
      TaskLogger.info("\n#{env.upcase} Environment:")
      config = ActiveRecord::Base.configurations.configs_for(env_name: env).first

      if config.is_a?(ActiveRecord::DatabaseConfigurations::UrlConfig)
        TaskLogger.info("  Using URL configuration")
        TaskLogger.info("  Database: #{config.database}")
        TaskLogger.info("  Host: #{config.host}")
      else
        TaskLogger.info("  Database: #{config.database}")
        TaskLogger.info("  Host: #{config.host}")
        TaskLogger.info("  Port: #{config.configuration_hash['port']}") if config.configuration_hash["port"]
        TaskLogger.info("  Username: #{config.configuration_hash['username']}") if config.configuration_hash["username"]
      end
    end
  end

  desc "Setup both development and test databases"
  task :setup_all do
    TaskLogger.info("Setting up all databases...")
    Rake::Task["db:setup_dev"].invoke
    Rake::Task["db:setup_test"].invoke
    TaskLogger.info("\nDatabase setup complete!")
  end

  desc "Setup development database"
  task :setup_dev do
    TaskLogger.info("\nSetting up development database...")
    system("RAILS_ENV=development bundle exec rake db:setup")
  end

  desc "Setup test database"
  task :setup_test do
    TaskLogger.info("\nSetting up test database...")
    system("RAILS_ENV=test bundle exec rake db:setup")
  end

  desc "Reset both development and test databases"
  task :reset_all do
    TaskLogger.info("Resetting all databases...")
    Rake::Task["db:reset_dev"].invoke
    Rake::Task["db:reset_test"].invoke
    TaskLogger.info("\nDatabase reset complete!")
  end

  desc "Reset development database"
  task :reset_dev do
    TaskLogger.info("\nResetting development database...")
    system("RAILS_ENV=development bundle exec rake db:drop db:create db:migrate db:seed")
  end

  desc "Reset test database"
  task :reset_test do
    TaskLogger.info("\nResetting test database...")
    system("RAILS_ENV=test bundle exec rake db:drop db:create db:migrate")
  end

  namespace :pool do
    desc "Check database connection pool status"
    task check: :environment do
      TaskLogger.info("Checking database connection pool...")

      pool = ActiveRecord::Base.connection_pool
      TaskLogger.info("Pool size: #{pool.size}")
      TaskLogger.info("Connections in use: #{pool.connections.count}")
      TaskLogger.info("Available connections: #{pool.size - pool.connections.count}")

      if pool.connections.count >= pool.size
        TaskLogger.warn("WARNING: All connections are in use!")
      end
    end

    desc "Clear idle connections in the pool"
    task clear_idle: :environment do
      TaskLogger.info("Clearing idle connections...")
      ActiveRecord::Base.connection_pool.disconnect!
      TaskLogger.info("Idle connections cleared.")
    end
  end

  namespace :test do
    desc "Prepare test database and optionally load sample data"
    task :prepare do
      TaskLogger.info("Preparing test database...")
      system("RAILS_ENV=test bundle exec rake db:test:prepare")

      if ENV["LOAD_SAMPLE_DATA"]
        Rake::Task["db:test:load_sample_data"].invoke
      end

      TaskLogger.info("\nTest database preparation complete!")
    end

    desc "Load sample data into test database"
    task load_sample_data: :environment do
      raise "This task must be run in test environment" unless Rails.env.test?
      # Add your sample data loading logic here
      TaskLogger.info("Sample data loaded successfully")
    end
  end
end
