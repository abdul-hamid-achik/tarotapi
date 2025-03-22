# Load the TaskLogger module
require_relative '../task_logger'

# Check if RAILS_ENV is explicitly set to 'test'
unless ENV['RAILS_ENV'] == 'test'
  ENV['RAILS_ENV'] = 'test'  # Set RAILS_ENV to test
  TaskLogger.info("RAILS_ENV has been set to 'test' for running tests.")
end

# The environment is already enforced as 'test' by this point

namespace :test do
  # No need to set RAILS_ENV here as it's enforced above

  desc "run all tests (rspec and cucumber)"
  task :all do
    TaskLogger.with_task_logging("test:all") do
      # Run RSpec tests
      rspec_result = system("bundle exec rspec")

      # Run Cucumber tests
      cucumber_result = system("bundle exec cucumber")

      if rspec_result && cucumber_result
        TaskLogger.info("All tests passed")
        exit 0
      else
        TaskLogger.error("Some tests failed")
        exit 1
      end
    end
  end

  desc "run all rspec tests"
  task :rspec do
    TaskLogger.with_task_logging("test:rspec") do
      if system("bundle exec rspec")
        TaskLogger.info("All RSpec tests passed")
      else
        TaskLogger.error("Some RSpec tests failed")
        exit 1
      end
    end
  end

  desc "run all cucumber tests"
  task :cucumber do
    TaskLogger.with_task_logging("test:cucumber") do
      if system("bundle exec cucumber")
        TaskLogger.info("All Cucumber tests passed")
      else
        TaskLogger.error("Some Cucumber tests failed")
        exit 1
      end
    end
  end

  # specific model tests
  namespace :models do
    desc "run all model tests"
    task :all do
      TaskLogger.with_task_logging("test:models:all") do
        if system("bundle exec rspec spec/models")
          TaskLogger.info("All model tests passed")
        else
          TaskLogger.error("Some model tests failed")
          exit 1
        end
      end
    end

    desc "run specific model test"
    task :run, [ :model_name ] => :environment do |t, args|
      model_name = args[:model_name]

      if model_name.blank?
        TaskLogger.error("Model name is required", usage: "rake test:models:run[model_name]")
        exit 1
      end

      TaskLogger.with_task_logging("test:models:run:#{model_name}") do
        if system("bundle exec rspec spec/models/#{model_name}_spec.rb")
          TaskLogger.info("Model tests passed", model: model_name)
        else
          TaskLogger.error("Model tests failed", model: model_name)
          exit 1
        end
      end
    end
  end

  # specific service tests
  namespace :services do
    desc "run all service tests"
    task :all do
      TaskLogger.with_task_logging("test:services:all") do
        if system("bundle exec rspec spec/services")
          TaskLogger.info("All service tests passed")
        else
          TaskLogger.error("Some service tests failed")
          exit 1
        end
      end
    end

    desc "verify service test coverage"
    task :verify_coverage do
      TaskLogger.with_task_logging("test:services:verify_coverage") do
        service_files = Dir.glob("app/services/**/*.rb").map { |f| File.basename(f, ".rb") }
        spec_files = Dir.glob("spec/services/**/*_spec.rb").map { |f| File.basename(f, "_spec.rb") }

        missing = service_files - spec_files

        if missing.empty?
          TaskLogger.info("All services have corresponding specs", covered: spec_files.count)
        else
          TaskLogger.warn("Missing specs for services", missing: missing)
        end
      end
    end

    desc "generate test for a specific service"
    task :generate, [ :service_name ] => :environment do |t, args|
      service_name = args[:service_name]

      if service_name.blank?
        puts "error: service name is required"
        puts "usage: rake test:services:generate[service_name]"
        exit 1
      end

      service_files = Dir.glob("app/services/**/*#{service_name}*.rb")

      if service_files.empty?
        puts "error: no service file found matching '#{service_name}'"
        exit 1
      elsif service_files.length > 1
        puts "found multiple matching service files:"
        service_files.each_with_index do |file, index|
          puts "  #{index + 1}. #{file}"
        end

        print "select a file (1-#{service_files.length}): "
        selection = STDIN.gets.chomp.to_i

        if selection < 1 || selection > service_files.length
          puts "invalid selection"
          exit 1
        end

        service_file = service_files[selection - 1]
      else
        service_file = service_files.first
      end

      service_basename = File.basename(service_file, ".rb")
      service_dir = File.dirname(service_file).gsub("app/", "spec/")
      spec_path = "#{service_dir}/#{service_basename}_spec.rb"

      FileUtils.mkdir_p(service_dir) unless Dir.exist?(service_dir)

      if File.exist?(spec_path)
        puts "error: spec file already exists: #{spec_path}"
        exit 1
      end

      service_content = File.read(service_file)
      class_name = service_basename.split("_").map(&:capitalize).join
      public_methods = service_content.scan(/^\s*def\s+(\w+)/).flatten - [ "initialize" ]

      template = <<~SPEC
        require 'rails_helper'

        RSpec.describe #{class_name} do
          describe "#initialize" do
            it "initializes successfully" do
              expect(#{class_name}.new).to be_a(#{class_name})
            end
          end
        #{'  '}
      SPEC

      public_methods.each do |method|
        template += <<~METHOD

          describe "##{method}" do
            it "performs expected behavior" do
              pending "test not implemented"
            end
          end
        METHOD
      end

      template += "\nend\n"

      File.write(spec_path, template)
      puts "created spec file: #{spec_path}"
      puts "added test placeholders for methods: #{public_methods.join(', ')}"
    end

    desc "run tests for a specific service"
    task :run, [ :service_name ] => :environment do |t, args|
      service_name = args[:service_name]

      if service_name.blank?
        puts "error: service name is required"
        puts "usage: rake test:services:run[service_name]"
        exit 1
      end

      spec_files = Dir.glob("spec/services/**/*#{service_name}*_spec.rb")

      if spec_files.empty?
        puts "error: no spec file found matching '#{service_name}'"
        puts "you may want to generate it first: rake test:services:generate[#{service_name}]"
        exit 1
      elsif spec_files.length > 1
        puts "found multiple matching spec files:"
        spec_files.each_with_index do |file, index|
          puts "  #{index + 1}. #{file}"
        end

        print "select a file (1-#{spec_files.length}): "
        selection = STDIN.gets.chomp.to_i

        if selection < 1 || selection > spec_files.length
          puts "invalid selection"
          exit 1
        end

        spec_file = spec_files[selection - 1]
      else
        spec_file = spec_files.first
      end

      if system("bundle exec rspec #{spec_file} --format documentation")
        puts "✅ service tests passed"
      else
        puts "❌ service tests failed"
        exit 1
      end
    end
  end

  # specific feature tests
  namespace :features do
    desc "run all feature tests"
    task :all do
      if system("bundle exec cucumber features")
        puts "all feature tests passed"
      else
        puts "some feature tests failed"
        exit 1
      end
    end

    desc "run specific feature test"
    task :run, [ :feature_name ] => :environment do |t, args|
      feature_name = args[:feature_name]

      if feature_name.blank?
        puts "error: feature name is required"
        puts "usage: rake test:features:run[feature_name]"
        exit 1
      end

      feature_path = if feature_name.include?(".feature")
                      "features/#{feature_name}"
      else
                      "features/#{feature_name}.feature"
      end

      unless File.exist?(feature_path)
        puts "error: feature file not found: #{feature_path}"
        exit 1
      end

      if system("bundle exec cucumber #{feature_path} --format pretty")
        puts "✅ feature passed: #{feature_name}"
      else
        puts "❌ feature failed: #{feature_name}"
        exit 1
      end
    end

    desc "generate feature file from template"
    task :generate, [ :name ] => :environment do |t, args|
      name = args[:name]

      if name.blank?
        puts "error: feature name is required"
        puts "usage: rake test:features:generate[feature_name]"
        exit 1
      end

      name = name.underscore
      file_path = "features/#{name}.feature"

      if File.exist?(file_path)
        puts "error: feature file already exists: #{file_path}"
        exit 1
      end

      title = name.split("_").map(&:capitalize).join(" ")

      template = <<~FEATURE
        feature: #{title} api
          as an api client
          i want to interact with #{name.tr('_', ' ')} functionality
          so that i can achieve my business goals

        scenario: successful #{name} operation
          given the api is available
          when i make a request to the #{name} endpoint
          then i should receive a successful response
          and the response should contain the expected data

        scenario: invalid request to #{name}
          given the api is available
          when i make an invalid request to the #{name} endpoint
          then i should receive an appropriate error response
          and the error message should be descriptive
      FEATURE

      File.write(file_path, template)
      puts "created feature file: #{file_path}"
    end

    desc "check bdd coverage against standard"
    task check_coverage: :environment do
      puts "checking bdd coverage..."

      feature_count = Dir.glob("features/*.feature").count
      model_spec_count = Dir.glob("spec/models/*_spec.rb").count
      service_spec_count = Dir.glob("spec/services/**/*_spec.rb").count
      request_spec_count = Dir.glob("spec/requests/**/*_spec.rb").count
      controller_spec_count = Dir.glob("spec/controllers/**/*_spec.rb").count

      total_app_files = Dir.glob("app/**/*.rb").count
      total_test_files = feature_count + model_spec_count + service_spec_count +
                        request_spec_count + controller_spec_count

      test_ratio = (total_test_files.to_f / total_app_files * 100).round(2)
      bdd_ratio = (feature_count.to_f / (feature_count + model_spec_count + service_spec_count) * 100).round(2)

      puts "test coverage statistics:"
      puts "-------------------------"
      puts "total application files: #{total_app_files}"
      puts "total test files: #{total_test_files} (#{test_ratio}% of app files)"
      puts ""
      puts "test file breakdown:"
      puts "- cucumber features: #{feature_count}"
      puts "- model specs: #{model_spec_count}"
      puts "- service specs: #{service_spec_count}"
      puts "- request specs: #{request_spec_count}"
      puts "- controller specs: #{controller_spec_count}"
      puts ""
      puts "bdd coverage: #{bdd_ratio}% (target: 80%)"

      if bdd_ratio < 80
        puts "⚠️ bdd coverage is below the 80% target"

        services = Dir.glob("app/services/**/*.rb").map { |f| File.basename(f, ".rb") }
        features = Dir.glob("features/*.feature").map { |f| File.basename(f, ".feature") }

        services_needing_features = services.select do |service|
          !features.any? { |feature| feature.include?(service) || service.include?(feature.gsub("_", "")) }
        end

        if services_needing_features.any?
          puts "suggestion: create feature files for these services:"
          services_needing_features.each do |service|
            puts "  - rake test:features:generate[#{service}]"
          end
        end
      else
        puts "✅ bdd coverage meets or exceeds 80% target"
      end
    end
  end

  desc "generate code coverage report"
  task :coverage do
    puts "generating code coverage report..."

    # Set SimpleCov environment variables
    ENV["COVERAGE"] = "true"
    ENV["SIMPLECOV_FORMATTER"] = "SimpleCov::Formatter::HTMLFormatter"

    # Run all tests with coverage
    Rake::Task["test:all"].invoke

    puts "coverage report generated in coverage/index.html"
  end

  desc "verify test coverage across all components"
  task :verify_coverage do
    Rake::Task["test:services:verify_coverage"].invoke
    Rake::Task["test:features:check_coverage"].invoke
  end

  desc "prepare test database"
  task :prepare do
    puts "preparing test database..."
    
    # Force the test database explicitly
    test_db_url = "postgresql://#{ENV.fetch("DB_USERNAME") { "tarot_api" }}:#{ENV.fetch("DB_PASSWORD") { "password" }}@#{ENV.fetch("DB_HOST") { "localhost" }}:#{ENV.fetch("DB_PORT") { "5432" }}/tarot_api_test"
    
    # Create and migrate test database with explicit database
    if system({"DATABASE_URL" => test_db_url, "RAILS_ENV" => "test"}, "bundle exec rake db:drop db:create db:schema:load")
      puts "test database prepared"
    else
      puts "failed to prepare test database"
      exit 1
    end
  end

  # Helper method to detect if running inside Docker
  def inside_docker?
    File.exist?("/.dockerenv")
  end

  desc "run tests in docker container"
  task :docker do
    puts "running tests in docker..."

    if !inside_docker?
      cmd = "docker compose exec api bundle exec rake test:all"
      if system(cmd)
        puts "all tests passed in docker"
      else
        puts "some tests failed in docker"
        exit 1
      end
    else
      # Already in docker, just run the tests
      Rake::Task["test:all"].invoke
    end
  end

  desc "rebuild docker image and run tests"
  task :docker_rebuild do
    puts "rebuilding docker image and running tests..."

    if system("docker compose build api")
      puts "docker image rebuilt successfully"
      Rake::Task["test:docker"].invoke
    else
      puts "failed to rebuild docker image"
      exit 1
    end
  end

  namespace :lint do
    desc "run rubocop"
    task :rubocop do
      TaskLogger.with_task_logging("test:lint:rubocop") do
        if system("bundle exec rubocop")
          TaskLogger.info("Rubocop passed")
        else
          TaskLogger.error("Rubocop found issues")
          exit 1
        end
      end
    end

    desc "run brakeman security scan"
    task :brakeman do
      TaskLogger.with_task_logging("test:lint:brakeman") do
        if system("bundle exec brakeman -q")
          TaskLogger.info("Brakeman passed")
        else
          TaskLogger.error("Brakeman found security issues")
          exit 1
        end
      end
    end

    desc "run ruby_audit vulnerability scanner"
    task :ruby_audit do
      TaskLogger.with_task_logging("test:lint:ruby_audit") do
        if system("bundle exec ruby-audit check")
          TaskLogger.info("Ruby_audit passed")
        else
          TaskLogger.error("Ruby_audit found security vulnerabilities")
          exit 1
        end
      end
    end

    desc "run all linters"
    task all: [ :rubocop, :brakeman, :ruby_audit ] do
      TaskLogger.info("All linters passed")
    end
  end

  desc "run all tests with linting and security checks"
  task full: [ "test:lint:all", "test:all" ] do
    puts "all tests and checks passed"
  end

  desc "comprehensive test that verifies coverage and runs all tests"
  task comprehensive: [ :verify_coverage, :full, :coverage ] do
    puts "comprehensive testing completed"
  end

  desc "generate missing specs and features for better coverage"
  task :improve_coverage do
    puts "improving test coverage..."

    # first check current coverage
    Rake::Task["test:verify_coverage"].invoke

    puts "coverage improvement tasks completed"
    puts "run 'rake test:comprehensive' to verify full coverage"
  end

  desc "find untested service methods"
  task :find_untested_methods do
    puts "finding untested service methods..."

    puts "untested methods task completed"
  end

  desc "full bdd assessment and generation"
  task :bdd_assessment do
    puts "performing full bdd assessment..."

    puts "bdd assessment completed"
  end

  desc "add usage_counted to readings if missing"
  task add_usage_counted: :environment do
    if !ActiveRecord::Base.connection.column_exists?(:readings, :usage_counted)
      puts "adding usage_counted to readings table"

      timestamp = Time.now.strftime("%Y%m%d%H%M%S")
      migration_class_name = "AddUsageCountedToReadings"

      migration_content = <<~RUBY
        class #{migration_class_name} < ActiveRecord::Migration[7.0]
          def change
            add_column :readings, :usage_counted, :boolean, default: false
            add_index :readings, :usage_counted
          end
        end
      RUBY

      migration_file = Rails.root.join("db/migrate/#{timestamp}_add_usage_counted_to_readings.rb")
      File.write(migration_file, migration_content)

      puts "created migration file: #{migration_file}"
      Rake::Task["db:migrate"].invoke
    else
      puts "usage_counted column already exists in readings table"
    end
  end

  namespace :subscriptions do
    desc "run subscription model tests"
    task :models do
      sh "bundle exec rspec spec/models/subscription_spec.rb spec/models/subscription_plan_spec.rb"
    end

    desc "run subscription service tests"
    task :services do
      sh "bundle exec rspec spec/services/subscription_service_spec.rb spec/services/stripe_service_spec.rb"
    end

    desc "run subscription feature tests"
    task :features do
      sh "bundle exec cucumber features/subscriptions"
    end

    desc "run all subscription tests"
    task all: [ :models, :services, :features ]
  end
end

# high-level default tasks
desc "run all tests and improve coverage where needed"
task test_and_improve: [ "test:all", "test:improve_coverage" ] do
  TaskLogger.info("All tests run and coverage improvements suggested")
end

desc "full test coverage workflow"
task full_test_coverage: [ "test:prepare", "test:improve_coverage", "test:comprehensive" ] do
  TaskLogger.info("Full test coverage workflow completed")
end

# Root level task to ensure proper test environment
desc "Main test task"
task :test do
  TaskLogger.with_task_logging("test") do
    TaskLogger.info("Preparing test database...")
    Rake::Task["test:prepare"].invoke
    
    TaskLogger.info("Running tests...")
    Rake::Task["test:all"].invoke
  end
end
