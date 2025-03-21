namespace :docker do
  desc "Clean up Docker resources (volumes, containers) for a fresh start"
  task :clean do
    puts Rainbow("Cleaning up Docker resources...").yellow
    
    # Stop all containers first
    puts "Stopping containers..."
    sh "docker-compose down" do |ok, status|
      # It's okay if this fails
    end
    
    # Remove the vendor directory
    Rake::Task["dev:clean_vendor"].invoke
    
    # Remove dangling volumes
    puts Rainbow("Removing unused Docker volumes...").yellow
    sh "docker volume prune -f" do |ok, status|
      # It's okay if this fails
    end
    
    # Pull fresh images
    puts Rainbow("Pulling latest base images...").yellow
    sh "docker-compose pull" do |ok, status|
      # It's okay if this fails
    end
    
    puts Rainbow("Docker cleanup complete!").green
    puts Rainbow("To rebuild completely, run: docker-compose up --build").cyan
  end
  
  desc "Rebuild Docker containers and start fresh"
  task :rebuild do
    Rake::Task["docker:clean"].invoke
    
    puts Rainbow("Rebuilding containers...").yellow
    sh "docker-compose build --no-cache"
    
    puts Rainbow("Starting services...").yellow
    sh "docker-compose up -d"
    
    puts Rainbow("Containers rebuilt and started!").green
  end
  
  desc "Show status of Docker containers"
  task :status do
    puts Rainbow("Docker container status:").cyan
    sh "docker-compose ps"
    
    puts "\n"
    puts Rainbow("Docker volume status:").cyan
    sh "docker volume ls | grep tarot_api"
  end
end 