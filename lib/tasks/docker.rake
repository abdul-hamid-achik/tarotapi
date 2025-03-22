namespace :docker do
  desc "Verify ARM architecture (required for this project)"
  task :verify_arm do
    arch = `uname -m`.strip
    TaskLogger.info("Detected architecture: #{arch}")

    if arch =~ /arm|aarch64/i
      TaskLogger.info("ARM architecture detected. Build can proceed.")
    else
      TaskLogger.warn("WARNING: Non-ARM architecture detected (#{arch})")
      TaskLogger.warn("This project is optimized for ARM (M1/M2/M3/M4) chips only.")
      TaskLogger.warn("Building on other architectures is not supported.")
      exit 1 unless ENV["FORCE_BUILD"] == "true"
      TaskLogger.warn("Proceeding anyway due to FORCE_BUILD=true")
    end
  end

  desc "Clean up Docker resources (volumes, containers) for a fresh start"
  task :clean do
    TaskLogger.info("Cleaning up Docker resources...")

    # Stop all containers first
    TaskLogger.info("Stopping containers...")
    sh "docker-compose down" do |ok, status|
      # It's okay if this fails
    end

    # Remove the vendor directory
    Rake::Task["dev:clean_vendor"].invoke

    # Remove dangling volumes
    TaskLogger.info("Removing unused Docker volumes...")
    sh "docker volume prune -f" do |ok, status|
      # It's okay if this fails
    end

    # Pull fresh images
    TaskLogger.info("Pulling latest base images...")
    sh "docker-compose pull" do |ok, status|
      # It's okay if this fails
    end

    TaskLogger.info("Docker cleanup complete!")
    TaskLogger.info("To rebuild completely, run: docker-compose up --build")
  end

  desc "Build Docker image (ARM-only) with optional target [development|production] and registry [ghcr|ecr|both]"
  task :build, [ :target, :registry ] => [ :verify_arm ] do |t, args|
    # Set defaults
    target = args[:target] || "development"
    tag = target == "production" ? "tarot_api:production" : "tarot_api:latest"
    registry = args[:registry]

    TaskLogger.info("Building ARM-optimized Docker image for #{target}")
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
        TaskLogger.error("Unknown registry: #{registry}. Use 'ghcr', 'ecr', or 'both'.")
      end
    end

    TaskLogger.info("Build complete. To run the image: docker run -p 3000:3000 #{tag}")
  end

  def push_to_ghcr(tag, target)
    TaskLogger.info("Pushing to GitHub Container Registry...")
    repo = ENV["GITHUB_REPOSITORY"] || "abdul-hamid-achik/tarot-api"
    ghcr_tag = "ghcr.io/#{repo}:#{target}"

    # Tag and push the image
    sh "docker tag #{tag} #{ghcr_tag}"
    sh "docker push #{ghcr_tag}" do |ok, status|
      if ok
        TaskLogger.info("✓ Successfully pushed #{ghcr_tag} to GitHub Container Registry")
      else
        TaskLogger.error("✗ Failed to push to GitHub Container Registry. Make sure you're logged in: docker login ghcr.io")
      end
    end
  end

  def push_to_ecr(tag, target)
    TaskLogger.info("Pushing to Amazon ECR...")

    # Get AWS region from environment or default
    region = ENV["AWS_REGION"] || ENV["AWS_DEFAULT_REGION"] || "mx-central-1"
    account_id = ENV["AWS_ACCOUNT_ID"]

    if !account_id
      TaskLogger.warn("⚠️ AWS_ACCOUNT_ID not set. Attempting to retrieve from AWS CLI...")
      # Try to get the AWS account ID
      account_id = `aws sts get-caller-identity --query Account --output text 2>/dev/null`.strip
      if account_id.empty?
        TaskLogger.error("✗ Failed to get AWS account ID. Set AWS_ACCOUNT_ID or ensure AWS CLI is configured.")
        return
      end
    end

    # Construct the ECR repository URL
    ecr_repo = ENV["ECR_REPOSITORY"] || "tarot-api"
    ecr_tag = "#{account_id}.dkr.ecr.#{region}.amazonaws.com/#{ecr_repo}:#{target}"

    # Log in to ECR
    TaskLogger.info("Logging in to Amazon ECR...")
    login_cmd = "aws ecr get-login-password --region #{region} | docker login --username AWS --password-stdin #{account_id}.dkr.ecr.#{region}.amazonaws.com"
    sh login_cmd do |ok, status|
      if !ok
        TaskLogger.error("✗ Failed to log in to Amazon ECR. Check your AWS credentials.")
        return
      end

      # Tag and push the image
      sh "docker tag #{tag} #{ecr_tag}"
      sh "docker push #{ecr_tag}" do |push_ok, push_status|
        if push_ok
          TaskLogger.info("✓ Successfully pushed #{ecr_tag} to Amazon ECR")
        else
          TaskLogger.error("✗ Failed to push to Amazon ECR. Check if repository exists: #{ecr_repo}")
        end
      end
    end
  end

  # Legacy tasks that use the new unified build task
  desc "[DEPRECATED] Build production Docker image (use docker:build[production] instead)"
  task build_production: [ :verify_arm ] do
    TaskLogger.warn("WARNING: This task is deprecated. Use docker:build[production] instead.")
    Rake::Task["docker:build"].invoke("production")
  end

  desc "Push the latest image to both GHCR and ECR registries"
  task :push_all, [ :target ] => [ :verify_arm ] do |t, args|
    target = args[:target] || "production"
    tag = target == "production" ? "tarot_api:production" : "tarot_api:latest"

    # Check if the image exists locally
    if system("docker image inspect #{tag} >/dev/null 2>&1")
      TaskLogger.info("Found #{tag} locally, pushing to registries...")
      push_to_ghcr(tag, target)
      push_to_ecr(tag, target)
    else
      TaskLogger.warn("Image #{tag} not found locally. Building first...")
      Rake::Task["docker:build"].invoke(target, "both")
    end
  end

  desc "Rebuild Docker containers and start fresh"
  task :rebuild do
    Rake::Task["docker:clean"].invoke

    TaskLogger.info("Rebuilding containers...")
    sh "docker-compose build --no-cache"

    TaskLogger.info("Starting services...")
    sh "docker-compose up -d"

    TaskLogger.info("Containers rebuilt and started!")
  end

  desc "Run tests in Docker container"
  task :test do
    TaskLogger.info("Running tests in Docker container")

    # Make sure we have the latest image
    Rake::Task["docker:build"].invoke unless ENV["CI"]

    # Run tests
    sh "docker run --rm -e RAILS_ENV=test tarot_api:latest bundle exec rake test"
  end

  desc "Start development environment with Docker Compose"
  task :start do
    TaskLogger.info("Starting development environment with Docker Compose")
    sh "docker-compose up -d"
  end

  desc "Stop development environment"
  task :stop do
    TaskLogger.info("Stopping development environment")
    sh "docker-compose down"
  end

  desc "Restart development environment"
  task :restart do
    Rake::Task["docker:stop"].invoke
    Rake::Task["docker:start"].invoke
  end

  desc "Show status of Docker containers"
  task :status do
    TaskLogger.info("Docker container status:")
    sh "docker-compose ps"

    TaskLogger.info("\nDocker volume status:")
    sh "docker volume ls | grep tarot_api"
  end

  desc "Import data and models to Docker volumes"
  task :import_resources do
    TaskLogger.warn("No resources to import - llama_cpp is disabled.")

    # Add code here if you need to import other resources in the future
  end
end