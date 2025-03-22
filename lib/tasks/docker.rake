namespace :docker do
  desc "Verify ARM architecture (required for this project)"
  task :verify_arm do
    arch = `uname -m`.strip
    puts Rainbow("Detected architecture: #{arch}").cyan

    if arch =~ /arm|aarch64/i
      puts Rainbow("ARM architecture detected. Build can proceed.").green
    else
      puts Rainbow("WARNING: Non-ARM architecture detected (#{arch})").bright.red
      puts Rainbow("This project is optimized for ARM (M1/M2/M3/M4) chips only.").bright.red
      puts Rainbow("Building on other architectures is not supported.").bright.red
      exit 1 unless ENV["FORCE_BUILD"] == "true"
      puts Rainbow("Proceeding anyway due to FORCE_BUILD=true").yellow
    end
  end

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

  desc "Build Docker image (ARM-only) with optional target [development|production] and registry [ghcr|ecr|both]"
  task :build, [ :target, :registry ] => [ :verify_arm ] do |t, args|
    # Set defaults
    target = args[:target] || "development"
    tag = target == "production" ? "tarot_api:production" : "tarot_api:latest"
    registry = args[:registry]

    puts Rainbow("Building ARM-optimized Docker image for #{target}").bright.green
    sh "docker build -t #{tag} --target #{target} --build-arg BUILDKIT_INLINE_CACHE=1 ."

    # Push to registry if requested
    if registry
      case registry
      when "ghcr"
        push_to_ghcr(tag, target)
      when "ecr"
        push_to_ecr(tag, target)
      when "both"
        push_to_ghcr(tag, target)
        push_to_ecr(tag, target)
      else
        puts Rainbow("Unknown registry: #{registry}. Use 'ghcr', 'ecr', or 'both'.").red
      end
    end

    puts Rainbow("Build complete. To run the image: docker run -p 3000:3000 #{tag}").green
  end

  def push_to_ghcr(tag, target)
    puts Rainbow("Pushing to GitHub Container Registry...").cyan
    repo = ENV["GITHUB_REPOSITORY"] || "your-org/tarot-api"
    ghcr_tag = "ghcr.io/#{repo}:#{target}"

    # Tag and push the image
    sh "docker tag #{tag} #{ghcr_tag}"
    sh "docker push #{ghcr_tag}" do |ok, status|
      if ok
        puts Rainbow("✓ Successfully pushed #{ghcr_tag} to GitHub Container Registry").green
      else
        puts Rainbow("✗ Failed to push to GitHub Container Registry. Make sure you're logged in: docker login ghcr.io").red
      end
    end
  end

  def push_to_ecr(tag, target)
    puts Rainbow("Pushing to Amazon ECR...").cyan

    # Get AWS region from environment or default
    region = ENV["AWS_REGION"] || ENV["AWS_DEFAULT_REGION"] || "mx-central-1"
    account_id = ENV["AWS_ACCOUNT_ID"]

    if !account_id
      puts Rainbow("⚠️ AWS_ACCOUNT_ID not set. Attempting to retrieve from AWS CLI...").yellow
      # Try to get the AWS account ID
      account_id = `aws sts get-caller-identity --query Account --output text 2>/dev/null`.strip
      if account_id.empty?
        puts Rainbow("✗ Failed to get AWS account ID. Set AWS_ACCOUNT_ID or ensure AWS CLI is configured.").red
        return
      end
    end

    # Construct the ECR repository URL
    ecr_repo = ENV["ECR_REPOSITORY"] || "tarot-api"
    ecr_tag = "#{account_id}.dkr.ecr.#{region}.amazonaws.com/#{ecr_repo}:#{target}"

    # Log in to ECR
    puts "Logging in to Amazon ECR..."
    login_cmd = "aws ecr get-login-password --region #{region} | docker login --username AWS --password-stdin #{account_id}.dkr.ecr.#{region}.amazonaws.com"
    sh login_cmd do |ok, status|
      if !ok
        puts Rainbow("✗ Failed to log in to Amazon ECR. Check your AWS credentials.").red
        return
      end

      # Tag and push the image
      sh "docker tag #{tag} #{ecr_tag}"
      sh "docker push #{ecr_tag}" do |push_ok, push_status|
        if push_ok
          puts Rainbow("✓ Successfully pushed #{ecr_tag} to Amazon ECR").green
        else
          puts Rainbow("✗ Failed to push to Amazon ECR. Check if repository exists: #{ecr_repo}").red
        end
      end
    end
  end

  # Legacy tasks that use the new unified build task
  desc "[DEPRECATED] Build production Docker image (use docker:build[production] instead)"
  task build_production: [ :verify_arm ] do
    puts Rainbow("WARNING: This task is deprecated. Use docker:build[production] instead.").yellow
    Rake::Task["docker:build"].invoke("production")
  end

  desc "Push the latest image to both GHCR and ECR registries"
  task :push_all, [ :target ] => [ :verify_arm ] do |t, args|
    target = args[:target] || "production"
    tag = target == "production" ? "tarot_api:production" : "tarot_api:latest"

    # Check if the image exists locally
    if system("docker image inspect #{tag} >/dev/null 2>&1")
      puts Rainbow("Found #{tag} locally, pushing to registries...").green
      push_to_ghcr(tag, target)
      push_to_ecr(tag, target)
    else
      puts Rainbow("Image #{tag} not found locally. Building first...").yellow
      Rake::Task["docker:build"].invoke(target, "both")
    end
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

  desc "Run tests in Docker container"
  task :test do
    puts Rainbow("Running tests in Docker container").bright.green

    # Make sure we have the latest image
    Rake::Task["docker:build"].invoke unless ENV["CI"]

    # Run tests
    sh "docker run --rm -e RAILS_ENV=test tarot_api:latest bundle exec rake test"
  end

  desc "Start development environment with Docker Compose"
  task :start do
    puts Rainbow("Starting development environment with Docker Compose").bright.green
    sh "docker-compose up -d"
  end

  desc "Stop development environment"
  task :stop do
    puts Rainbow("Stopping development environment").yellow
    sh "docker-compose down"
  end

  desc "Restart development environment"
  task :restart do
    Rake::Task["docker:stop"].invoke
    Rake::Task["docker:start"].invoke
  end

  desc "Show status of Docker containers"
  task :status do
    puts Rainbow("Docker container status:").cyan
    sh "docker-compose ps"

    puts "\n"
    puts Rainbow("Docker volume status:").cyan
    sh "docker volume ls | grep tarot_api"
  end

  desc "Import data and models to Docker volumes"
  task :import_resources do
    puts Rainbow("No resources to import - llama_cpp is disabled.").yellow

    # Add code here if you need to import other resources in the future
  end
end
