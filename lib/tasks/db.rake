namespace :db do
  desc "Check database configuration for all environments"
  task check_config: :environment do
    puts "\nChecking database configuration..."

    %w[development test production].each do |env|
      puts "\n#{env.upcase} Environment:"
      config = ActiveRecord::Base.configurations.configs_for(env_name: env).first

      if config.is_a?(ActiveRecord::DatabaseConfigurations::UrlConfig)
        puts "  Using URL configuration"
        puts "  Database: #{config.database}"
        puts "  Host: #{config.host}"
      else
        puts "  Database: #{config.database}"
        puts "  Host: #{config.host}"
        puts "  Port: #{config.configuration_hash['port']}" if config.configuration_hash["port"]
        puts "  Username: #{config.configuration_hash['username']}" if config.configuration_hash["username"]
      end
    end
  end

  desc "Setup both development and test databases"
  task :setup_all do
    puts "Setting up all databases..."

    puts "\nSetting up development database..."
    system("RAILS_ENV=development bundle exec rake db:setup")

    puts "\nSetting up test database..."
    system("RAILS_ENV=test bundle exec rake db:setup")

    puts "\nDatabase setup complete!"
  end

  desc "Reset both development and test databases"
  task :reset_all do
    puts "Resetting all databases..."

    puts "\nResetting development database..."
    system("RAILS_ENV=development bundle exec rake db:drop db:create db:migrate db:seed")

    puts "\nResetting test database..."
    system("RAILS_ENV=test bundle exec rake db:drop db:create db:migrate")

    puts "\nDatabase reset complete!"
  end

  desc "Prepare test database and optionally load sample data"
  task :prepare_all do
    puts "Preparing test database..."
    system("RAILS_ENV=test bundle exec rake db:test:prepare")

    if ENV["LOAD_SAMPLE_DATA"]
      puts "\nLoading sample data..."
      system("RAILS_ENV=test bundle exec rake db:test:load_sample_data")
    end

    puts "\nTest database preparation complete!"
  end

  namespace :test do
    desc "Load sample data into test database"
    task load_sample_data: :environment do
      raise "This task must be run in test environment" unless Rails.env.test?
      # Add your sample data loading logic here
      puts "Sample data loaded successfully"
    end
  end
end
