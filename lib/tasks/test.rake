namespace :test do
  desc "run all tests (rspec and cucumber)"
  task :all do
    puts "running all tests..."

    # Run RSpec tests
    rspec_result = system("bundle exec rspec")

    # Run Cucumber tests
    cucumber_result = system("bundle exec cucumber")

    if rspec_result && cucumber_result
      puts "all tests passed"
      exit 0
    else
      puts "some tests failed"
      exit 1
    end
  end

  desc "run all rspec tests"
  task :rspec do
    if system("bundle exec rspec")
      puts "all rspec tests passed"
    else
      puts "some rspec tests failed"
      exit 1
    end
  end

  desc "run all cucumber tests"
  task :cucumber do
    if system("bundle exec cucumber")
      puts "all cucumber tests passed"
    else
      puts "some cucumber tests failed"
      exit 1
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

  desc "prepare test database"
  task :prepare do
    puts "preparing test database..."

    # Create and migrate test database
    if system("RAILS_ENV=test bundle exec rake db:drop db:create db:schema:load")
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
      if system("bundle exec rubocop")
        puts "rubocop passed"
      else
        puts "rubocop found issues"
        exit 1
      end
    end

    desc "run brakeman security scan"
    task :brakeman do
      if system("bundle exec brakeman -q")
        puts "brakeman passed"
      else
        puts "brakeman found security issues"
        exit 1
      end
    end

    desc "run all linters"
    task all: [ :rubocop, :brakeman ] do
      puts "all linters passed"
    end
  end

  desc "run all tests with linting and security checks"
  task full: [ "test:lint:all", "test:all" ] do
    puts "all tests and checks passed"
  end
end
