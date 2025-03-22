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
        TaskLogger.info("  Port: #{config.configuration_hash['port']}" ) if config.configuration_hash["port"]
        TaskLogger.info("  Username: #{config.configuration_hash['username']}" ) if config.configuration_hash["username"]
      end
    end
  end

  desc "Setup both development and test databases"
  task :setup_all do
    TaskLogger.info("Setting up all databases...")

    TaskLogger.info("\nSetting up development database...")
    system("RAILS_ENV=development bundle exec rake db:setup")

    TaskLogger.info("\nSetting up test database...")
    system("RAILS_ENV=test bundle exec rake db:setup")

    TaskLogger.info("\nDatabase setup complete!")
  end

  desc "Reset both development and test databases"
  task :reset_all do
    TaskLogger.info("Resetting all databases...")

    TaskLogger.info("\nResetting development database...")
    system("RAILS_ENV=development bundle exec rake db:drop db:create db:migrate db:seed")

    TaskLogger.info("\nResetting test database...")
    system("RAILS_ENV=test bundle exec rake db:drop db:create db:migrate")

    TaskLogger.info("\nDatabase reset complete!")
  end

  desc "Prepare test database and optionally load sample data"
  task :prepare_all do
    TaskLogger.info("Preparing test database...")
    system("RAILS_ENV=test bundle exec rake db:test:prepare")

    if ENV["LOAD_SAMPLE_DATA"]
      TaskLogger.info("\nLoading sample data...")
      system("RAILS_ENV=test bundle exec rake db:test:load_sample_data")
    end

    TaskLogger.info("\nTest database preparation complete!")
  end

  namespace :test do
    desc "Load sample data into test database"
    task load_sample_data: :environment do
      raise "This task must be run in test environment" unless Rails.env.test?
      # Add your sample data loading logic here
      TaskLogger.info("Sample data loaded successfully")
    end
  end
end
