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
end

# Default task for development
desc "start development environment (alias for dev:start)"
task dev: "dev:start" 