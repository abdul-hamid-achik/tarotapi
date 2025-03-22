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
    required_ruby = File.read('.ruby-version').strip
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
    system("yarn install") if File.exist?('package.json')
  end

  desc "Seed sample data for development"
  task seed_sample_data: :environment do
    TaskLogger.info("Seeding sample data...")
    
    # Add your sample data seeding logic here
    # For example:
    if defined?(User)
      unless User.find_by(email: 'admin@example.com')
        User.create!(
          email: 'admin@example.com',
          password: 'password',
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
    FileUtils.rm_rf(Rails.root.join('tmp/cache'))
    FileUtils.rm_rf(Rails.root.join('tmp/pids'))
    FileUtils.rm_rf(Rails.root.join('tmp/sessions'))
    
    # Clean logs
    FileUtils.rm_rf(Rails.root.join('log/*.log'))
    
    # Clean test files
    FileUtils.rm_rf(Rails.root.join('coverage'))
    FileUtils.rm_rf(Rails.root.join('spec/reports'))
    
    TaskLogger.info("Development environment cleaned!")
  end
end

namespace :test do
  desc "Run all tests"
  task :all do
    TaskLogger.info("Running all tests...")
    
    Rake::Task["test:prepare"].invoke
    Rake::Task["test:unit"].invoke
    Rake::Task["test:integration"].invoke
    Rake::Task["test:system"].invoke
    
    TaskLogger.info("All tests completed!")
  end

  desc "Prepare test environment"
  task :prepare do
    TaskLogger.info("Preparing test environment...")
    
    # Ensure test database is ready
    system("RAILS_ENV=test bundle exec rake db:test:prepare")
    
    # Clear test logs
    FileUtils.rm_f(Rails.root.join('log/test.log'))
  end

  desc "Run unit tests"
  task :unit do
    TaskLogger.info("Running unit tests...")
    system("bundle exec rspec spec/models spec/services spec/helpers")
  end

  desc "Run integration tests"
  task :integration do
    TaskLogger.info("Running integration tests...")
    system("bundle exec rspec spec/requests spec/controllers")
  end

  desc "Run system tests"
  task :system do
    TaskLogger.info("Running system tests...")
    system("bundle exec rspec spec/system")
  end

  namespace :coverage do
    desc "Generate test coverage report"
    task :report do
      TaskLogger.info("Generating test coverage report...")
      
      ENV['COVERAGE'] = 'true'
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
    Rake::Task["test:all"].invoke
    
    TaskLogger.info("CI checks completed!")
  end

  desc "Run linting checks"
  task :lint do
    TaskLogger.info("Running linting checks...")
    
    # Run RuboCop
    system("bundle exec rubocop")
    
    # Run ESLint if JavaScript files exist
    if File.exist?('package.json')
      system("yarn lint")
    end
  end

  desc "Run security checks"
  task :security do
    TaskLogger.info("Running security checks...")
    
    # Check for vulnerable dependencies
    system("bundle exec bundle audit check --update")
    
    # Run Brakeman for security analysis
    system("bundle exec brakeman -q -w2")
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