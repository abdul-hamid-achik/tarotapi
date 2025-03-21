namespace :dev do
  desc "setup local development environment"
  task :setup do
    puts "setting up development environment..."

    # Check for Docker
    unless system("which docker > /dev/null 2>&1")
      abort "error: docker is not installed. please install docker"
    end

    # Install dependencies
    system("bundle install") || abort("failed to install bundle dependencies")

    # Setup Docker environment
    system("docker compose build") || abort("failed to build containers")

    puts "starting containers..."
    system("docker compose up -d") || abort("failed to start containers")

    # Wait for database to be ready
    30.times do
      break if system("docker compose exec -T postgres pg_isready -U tarot_api > /dev/null 2>&1")
      print "."
      sleep 1
    end
    puts ""

    # Setup database
    system("docker compose exec -T api bundle exec rails db:setup") || abort("failed to setup database")

    # Setup MinIO buckets
    system("docker compose exec -T minio mc alias set local http://localhost:9000 minioadmin minioadmin")
    system("docker compose exec -T minio mc mb local/tarot-api --ignore-existing")
    system("docker compose exec -T minio mc anonymous set download local/tarot-api")

    puts "development environment setup complete!"
  end

  desc "start the development environment"
  task :start do
    puts "starting development environment..."

    if system("docker compose ps | grep -q 'Up'")
      puts "containers already running"
    else
      system("docker compose up -d") || abort("failed to start containers")

      puts "waiting for containers to be ready..."
      30.times do
        break if system("docker compose ps api | grep -q 'Up'")
        print "."
        sleep 1
      end
      puts ""

      if system("docker compose ps api | grep -q 'Up'")
        puts "development environment started successfully"
      else
        abort "failed to start development environment"
      end
    end
  end

  desc "stop the development environment"
  task :stop do
    puts "stopping development environment..."
    system("docker compose stop") || abort("failed to stop containers")
    puts "development environment stopped"
  end

  desc "restart the development environment"
  task :restart do
    Rake::Task["dev:stop"].invoke
    Rake::Task["dev:start"].invoke
    puts "development environment restarted"
  end

  desc "rebuild development environment"
  task :rebuild do
    puts "rebuilding development environment..."
    system("docker compose down -v") || abort("failed to remove containers")
    system("docker compose build --no-cache") || abort("failed to rebuild containers")
    Rake::Task["dev:start"].invoke
    puts "development environment rebuilt and started"
  end

  desc "open a rails console in development"
  task :console do
    Rake::Task["dev:start"].invoke
    puts "starting rails console..."
    exec("docker compose exec api bundle exec rails console")
  end

  desc "open a database console in development"
  task :dbconsole do
    Rake::Task["dev:start"].invoke
    puts "starting database console..."
    exec("docker compose exec api bundle exec rails dbconsole")
  end

  desc "run tests in development environment"
  task :test do
    Rake::Task["dev:start"].invoke
    puts "running tests..."
    system("docker compose exec api bundle exec rails test") || abort("tests failed")
    puts "tests completed successfully"
  end
  desc "fixes common lint issues"
  task :fix do
    system("docker compose exec api bundle exec rubocop --auto-correct") || abort("failed to run rubocop")
    puts "lint issues fixed"
  end

  desc "view development logs"
  task :logs do
    exec("docker compose logs -f")
  end

  desc "run health check on development environment"
  task :health do
    Rake::Task["dev:start"].invoke
    puts "checking development environment health..."
    system("docker compose exec api bundle exec rails runner 'puts \"Database connected: #{ActiveRecord::Base.connected?}\"'")
    system("docker compose exec api curl -s http://localhost:3000/health")
    puts "health check completed"
  end

  desc "install llama_cpp for ARM architecture"
  task :install_llama_cpp do
    puts "Installing llama.cpp for ARM architecture..."

    # Check if Homebrew is installed
    unless system("which brew > /dev/null 2>&1")
      abort "Error: Homebrew is not installed. Please install Homebrew first: https://brew.sh"
    end

    # Install llama.cpp using Homebrew
    puts "Installing llama.cpp using Homebrew..."
    system("brew install llama.cpp") || abort("Failed to install llama.cpp via Homebrew")

    # Set up bundler configuration for the llama_cpp gem
    puts "Configuring bundler for llama_cpp gem..."
    system("bundle config --local build.llama_cpp --with-opt-dir=/opt/homebrew/") ||
      abort("Failed to configure bundler for llama_cpp")

    # Install the gem with the right configuration
    puts "Installing llama_cpp gem..."
    if system("bundle install")
      puts "✅ Successfully installed llama_cpp gem"
    else
      puts "❌ Failed to install the gem through bundler"
      puts "Try reinstalling Xcode (not just the command line tools)"
      puts "1. Install Xcode from the App Store"
      puts "2. Run 'sudo xcode-select -r' to reset the developer directory"
      puts "3. Run 'bundle install' again"
    end
  end

  desc "Clean up vendor directory to prevent local gem installations"
  task :clean_vendor do
    puts Rainbow("Cleaning up vendor directory...").yellow
    
    # Check if running in Docker
    in_docker = File.exist?('/.dockerenv')
    
    if in_docker
      puts Rainbow("Running inside Docker container, skipping vendor cleanup").cyan
    else
      if Dir.exist?(File.join(Rails.root, 'vendor'))
        puts Rainbow("Removing vendor directory content").yellow
        sh "rm -rf #{Rails.root}/vendor/bundle"
        puts Rainbow("Vendor directory cleaned").green
      else
        puts Rainbow("No vendor directory found, nothing to clean").green
      end
    end
    
    puts Rainbow("Tip: Make sure your Docker setup mounts gems in a volume, not in the local vendor directory").cyan
    puts Rainbow("Add this to your docker-compose.yml:").cyan
    puts Rainbow("  volumes:").cyan
    puts Rainbow("    - gem_cache:/usr/local/bundle").cyan
    puts Rainbow("  # Instead of:").cyan
    puts Rainbow("  # - ./vendor/bundle:/usr/local/bundle").cyan
  end
end

# Default task for development
desc "start development environment (alias for dev:start)"
task dev: "dev:start"
