require "dotenv"
require "semantic_logger"
require_relative "../task_logger"

namespace :deploy do
  desc "Deploy the application with zero downtime"
  task :production do
    TaskLogger.info("Starting zero-downtime deployment to production...")
    TaskLogger.info("Checking if production infrastructure exists...")

    # First check if we need to deploy infrastructure
    infra_exists = false
    Dir.chdir(File.expand_path("../../infrastructure", __dir__)) do
      # Switch to production stack
      system("pulumi stack select production")
      # Check if we have any outputs (indicating resources were deployed)
      output = `pulumi stack output --json`.strip
      infra_exists = output != "{}" && !output.empty?
    end

    unless infra_exists
      TaskLogger.info("Production infrastructure not found. Deploying infrastructure first...")
      Rake::Task["infra:deploy"].invoke("production")
    end

    # Now proceed with application deployment
    Rake::Task["deploy:check_prerequisites"].invoke
    Rake::Task["deploy:build"].invoke("production")
    Rake::Task["deploy:push"].invoke("production")

    # Try to update registry but don't fail if cluster doesn't exist yet
    begin
      Rake::Task["deploy:update_registry"].invoke("production")
    rescue StandardError => e
      TaskLogger.warn("Could not update ECS service: #{e.message}")
      TaskLogger.warn("You may need to manually update the ECS service or run 'rake infra:deploy[production]' first.")
    end

    TaskLogger.info("Deployment completed!")
  end

  desc "Deploy to staging environment"
  task :staging do
    TaskLogger.info("Starting deployment to staging...")

    # Check if we need to deploy infrastructure
    infra_exists = false
    Dir.chdir(File.expand_path("../../infrastructure", __dir__)) do
      # Switch to staging stack
      system("pulumi stack select staging")
      # Check if we have any outputs (indicating resources were deployed)
      output = `pulumi stack output --json`.strip
      infra_exists = output != "{}" && !output.empty?
    end

    unless infra_exists
      TaskLogger.info("Staging infrastructure not found. Deploying infrastructure first...")
      Rake::Task["infra:deploy"].invoke("staging")
    end

    Rake::Task["deploy:check_prerequisites"].invoke
    Rake::Task["deploy:build"].invoke("staging")
    Rake::Task["deploy:push"].invoke("staging")
    Rake::Task["deploy:update_registry"].invoke("staging")
    TaskLogger.info("Staging deployment completed successfully!")
  end

  desc "Check deployment prerequisites"
  task :check_prerequisites do
    TaskLogger.info("Checking deployment prerequisites...")

    # Check cloud provider credentials
    unless system("aws sts get-caller-identity > /dev/null 2>&1")
      TaskLogger.error("Cloud provider credentials not configured properly")
      raise "Cloud provider credentials not configured properly"
    end

    # Check container runtime
    unless system("docker info > /dev/null 2>&1")
      TaskLogger.error("Container runtime is not running or not installed")
      raise "Container runtime is not running or not installed"
    end

    TaskLogger.info("Prerequisites check passed!")
  end

  desc "Build container image"
  task :build, [ :env ] do |t, args|
    env = args[:env] || "production"
    TaskLogger.info("Building container image for #{env}...")

    system("docker build -t tarot-api:#{env} \
      --build-arg RAILS_ENV=#{env} \
      --build-arg RAILS_MASTER_KEY=#{ENV['RAILS_MASTER_KEY']} \
      .")
  end

  desc "Push container image to registry"
  task :push, [ :env ] do |t, args|
    env = args[:env] || "production"
    registry = ENV["CONTAINER_REGISTRY"]

    if registry.nil?
      TaskLogger.info("CONTAINER_REGISTRY not set, attempting to get it from Pulumi outputs...")

      # For development env, default to GitHub Container Registry if not set
      if env == "development"
        registry = "ghcr.io/#{ENV['GITHUB_REPOSITORY_OWNER'] || 'abdul-hamid-achik'}/tarot-api"
        TaskLogger.info("Using GitHub Container Registry for development: #{registry}")
      else
        # Change directory to infrastructure folder
        Dir.chdir(File.expand_path("../../infrastructure", __dir__)) do
          # Try to get the container registry from Pulumi output
          output = `pulumi stack output containerRegistry --stack #{env} 2>/dev/null`.strip

          # Parse the output - match the exact format we're seeing
          if output =~ /^\{"value":"([^"]+)"\}$/
            registry = $1
            TaskLogger.info("Extracted registry URL from JSON output: #{registry}")
          elsif output =~ /^"(.+)"$/
            registry = $1
            TaskLogger.info("Extracted registry URL from quoted string: #{registry}")
          else
            registry = output
            TaskLogger.info("Using registry URL as-is: #{registry}")
          end

          if registry.nil? || registry.empty?
            raise "CONTAINER_REGISTRY not set and could not be retrieved from Pulumi outputs"
          else
            TaskLogger.info("Using container registry from Pulumi outputs: #{registry}")
          end
        end
      end
    end

    TaskLogger.info("Pushing container image to #{registry}...")
    # Need to login to ECR first
    if registry.include?("ecr") && registry.include?("amazonaws.com")
      TaskLogger.info("Logging in to ECR...")
      system("aws ecr get-login-password --region #{ENV['AWS_DEFAULT_REGION']} | docker login --username AWS --password-stdin #{registry.split('/')[0]}")
    end

    # Tag and push to the repository
    system("docker tag tarot-api:#{env} #{registry}:#{env}")
    system("docker push #{registry}:#{env}")
  end

  desc "Clean up old container images"
  task :cleanup do
    TaskLogger.info("Cleaning up old container images...")
    system("docker image prune -f --filter 'until=24h'")
    TaskLogger.info("Cleanup completed!")
  end

  desc "Update container registry"
  task :update_registry, [ :env ] do |t, args|
    env = args[:env] || "production"
    cluster_var_name = "CLUSTER_NAME_#{env.upcase}"
    service_var_name = "SERVICE_NAME_#{env.upcase}"

    cluster = ENV[cluster_var_name]
    service = ENV[service_var_name]

    if cluster.nil? || service.nil?
      TaskLogger.info("#{cluster_var_name} or #{service_var_name} not set, attempting to get from Pulumi outputs...")

      Dir.chdir(File.expand_path("../../infrastructure", __dir__)) do
        if cluster.nil?
          # Try to get the cluster name from Pulumi output
          output = `pulumi stack output ecsClusterId --stack #{env} 2>/dev/null`.strip

          # Parse the output - match the exact format we're seeing
          if output =~ /^\{"value":"([^"]+)"\}$/
            cluster_arn = $1
            # Extract cluster name from ARN
            if cluster_arn =~ /cluster\/([\w-]+)$/
              cluster = $1
              TaskLogger.info("Using cluster name from Pulumi outputs: #{cluster}")
            end
          elsif output =~ /^"(.+)"$/
            cluster_arn = $1
            # Extract cluster name from ARN
            if cluster_arn =~ /cluster\/([\w-]+)$/
              cluster = $1
              TaskLogger.info("Using cluster name from Pulumi outputs: #{cluster}")
            end
          else
            # Try to extract cluster ARN directly
            if output =~ /cluster\/([\w-]+)$/
              cluster = $1
              TaskLogger.info("Using cluster name from direct output: #{cluster}")
            end
          end
        end

        if service.nil?
          # Use a default service name based on environment if not found
          service = "tarot-api-ecs-service-#{env}"
          TaskLogger.info("Using default service name: #{service}")
        end
      end
    end

    # Raise error if still not set but only if specific resources exist in this environment
    if cluster.nil?
      # Check if we have any resources deployed at all
      Dir.chdir(File.expand_path("../../infrastructure", __dir__)) do
        output = `pulumi stack output --json --stack #{env} 2>/dev/null`.strip
        if output == "{}" || output.empty?
          TaskLogger.warn("No resources found in #{env} environment")
          TaskLogger.warn("You may need to run 'rake infra:deploy[#{env}]' first to create the infrastructure")
          return # Exit the task without raising an error
        else
          raise "#{cluster_var_name} not set and could not be determined from Pulumi outputs"
        end
      end
    end

    raise "#{service_var_name} not set" if service.nil?

    TaskLogger.info("Updating container registry in #{env}...")
    # Use --no-cli-pager to avoid opening vim and pipe through a JSON formatter
    json_output = `aws ecs update-service --no-cli-pager --cluster #{cluster} --service #{service} --force-new-deployment`

    begin
      # Try to parse and prettify the JSON
      require "json"
      parsed_json = JSON.parse(json_output)
      pretty_json = JSON.pretty_generate(parsed_json)

      # Print the prettified JSON with some formatting
      TaskLogger.info "----- Service Update Result -----"
      TaskLogger.info pretty_json
      TaskLogger.info "--------------------------------"
    rescue => e
      # If JSON parsing fails, just output the raw result
      TaskLogger.info json_output
    end
  end

  desc "Scale service"
  task :scale, [ :env, :count ] do |t, args|
    env = args[:env] || "production"
    count = args[:count] || raise("Count required")
    cluster = ENV["CLUSTER_NAME_#{env.upcase}"]
    service = ENV["SERVICE_NAME_#{env.upcase}"]

    TaskLogger.info("Scaling service to #{count} tasks...")
    system("aws ecs update-service --cluster #{cluster} --service #{service} --desired-count #{count}")
  end

  namespace :health do
    desc "Check deployment health"
    task :check, [ :env ] do |t, args|
      env = args[:env] || "production"
      endpoint = ENV["HEALTH_CHECK_ENDPOINT_#{env.upcase}"] || raise("HEALTH_CHECK_ENDPOINT_#{env.upcase} not set")

      TaskLogger.info("Performing health check...")
      require "net/http"
      uri = URI(endpoint)

      5.times do |i|
        begin
          response = Net::HTTP.get_response(uri)
          if response.code == "200"
            TaskLogger.info("Health check passed!")
            exit 0
          end
        rescue StandardError => e
          TaskLogger.warn("Health check attempt #{i+1} failed: #{e.message}")
        end
        sleep 5
      end

      TaskLogger.error("Health check failed after 5 attempts")
      raise "Health check failed after 5 attempts"
    end

    desc "Monitor deployment logs"
    task :logs, [ :env ] do |t, args|
      env = args[:env] || "production"
      cluster = ENV["CLUSTER_NAME_#{env.upcase}"]
      service = ENV["SERVICE_NAME_#{env.upcase}"]

      TaskLogger.info("Fetching deployment logs...")
      system("aws logs tail #{cluster}-#{service} --follow")
    end
  end

  desc "Deploy to multiple environments with zero-downtime approach (staging then production)"
  task :pipeline, [ :confirm_prod ] do |t, args|
    confirm_prod = args[:confirm_prod]&.downcase == "y"

    begin
      TaskLogger.info("Starting deployment pipeline (staging first)...")

      # Deploy to staging first
      Rake::Task["deploy:staging"].invoke

      # Check if staging deployment was successful
      TaskLogger.info("Verifying staging deployment health...")
      Rake::Task["deploy:health:check"].invoke("staging")

      # If staging is healthy, prompt for production deployment unless auto-confirmed
      unless confirm_prod
        puts "\n"
        puts "======================================================================"
        puts "✅ Staging deployment complete and healthy."
        puts "Do you want to proceed with production deployment? (y/n)"
        puts "======================================================================"
        puts "\n"

        # Wait for user input
        response = STDIN.gets.chomp.downcase
        confirm_prod = response == "y"
      end

      if confirm_prod
        TaskLogger.info("Proceeding with production deployment...")
        # Reenable health check task so it can be called again
        Rake::Task["deploy:health:check"].reenable

        # Deploy to production
        Rake::Task["deploy:production"].invoke

        # Check production health
        TaskLogger.info("Verifying production deployment health...")
        Rake::Task["deploy:health:check"].reenable
        Rake::Task["deploy:health:check"].invoke("production")

        TaskLogger.info("✅ Full deployment pipeline completed successfully!")
      else
        TaskLogger.info("Production deployment skipped. Staging deployment is complete.")
      end
    rescue => e
      TaskLogger.error("❌ Deployment pipeline failed: #{e.message}")
      TaskLogger.error(e.backtrace.join("\n"))
      exit 1
    end
  end
end

# Convenience aliases
namespace :container do
  desc "Alias for deploy:build"
  task :build, [ :env ] => "deploy:build"

  desc "Alias for deploy:push"
  task :push, [ :env ] => "deploy:push"

  desc "Alias for deploy:cleanup"
  task cleanup: "deploy:cleanup"
end

# Also add a complementary task for infrastructure deployment
namespace :infra do
  desc "Deploy infrastructure to multiple environments sequentially (staging then production)"
  task :pipeline, [ :confirm_prod ] do |t, args|
    confirm_prod = args[:confirm_prod]&.downcase == "y"

    begin
      TaskLogger.info("Starting infrastructure deployment pipeline (staging first)...")

      # Deploy staging infrastructure
      Rake::Task["infra:deploy"].invoke("staging")
      TaskLogger.info("✅ Staging infrastructure deployed successfully.")

      # Unless auto-confirmed, prompt for production deployment
      unless confirm_prod
        puts "\n"
        puts "======================================================================"
        puts "✅ Staging infrastructure deployment complete."
        puts "Do you want to proceed with production infrastructure deployment? (y/n)"
        puts "======================================================================"
        puts "\n"

        # Wait for user input
        response = STDIN.gets.chomp.downcase
        confirm_prod = response == "y"
      end

      if confirm_prod
        TaskLogger.info("Proceeding with production infrastructure deployment...")
        # Reenable the infra:deploy task
        Rake::Task["infra:deploy"].reenable

        # Deploy to production
        Rake::Task["infra:deploy"].invoke("production")
        TaskLogger.info("✅ Full infrastructure deployment pipeline completed successfully!")
      else
        TaskLogger.info("Production infrastructure deployment skipped. Staging deployment is complete.")
      end
    rescue => e
      TaskLogger.error("❌ Infrastructure deployment pipeline failed: #{e.message}")
      TaskLogger.error(e.backtrace.join("\n"))
      exit 1
    end
  end
end

# Add a comprehensive release process that handles both infrastructure and application deployment
namespace :release do
  desc "Perform a full release (build, test, deploy to staging, then production)"
  task :execute, [ :version, :confirm_prod ] do |t, args|
    version = args[:version]
    confirm_prod = args[:confirm_prod]&.downcase == "y"

    if version.nil? || version.empty?
      time_stamp = Time.now.strftime("%Y%m%d%H%M")
      version = "v#{time_stamp}"
      TaskLogger.info("No version specified, using generated version: #{version}")
    end

    begin
      TaskLogger.info("Starting release process for version: #{version}")

      # Step 1: Verify prerequisites
      TaskLogger.info("Checking deployment prerequisites...")
      Rake::Task["deploy:check_prerequisites"].invoke

      # Step 2: Run tests if available
      if Rake::Task.task_defined?("test:all")
        TaskLogger.info("Running tests...")
        Rake::Task["test:all"].invoke
      end

      # Step 3: Deploy infrastructure to staging
      TaskLogger.info("Deploying infrastructure to staging...")
      Rake::Task["infra:deploy"].invoke("staging")
      TaskLogger.info("✅ Staging infrastructure deployed")

      # Step 4: Build and push the container
      TaskLogger.info("Building and pushing container...")
      Rake::Task["deploy:build"].invoke("staging")
      Rake::Task["deploy:push"].invoke("staging")

      # Step 5: Update the registry for staging
      TaskLogger.info("Updating registry for staging...")
      Rake::Task["deploy:update_registry"].invoke("staging")

      # Step 6: Health check on staging
      TaskLogger.info("Checking staging deployment health...")
      Rake::Task["deploy:health:check"].invoke("staging")
      TaskLogger.info("✅ Staging deployment healthy")

      # Step 7: Prompt for production deployment unless auto-confirmed
      unless confirm_prod
        puts "\n"
        puts "=============================================================="
        puts "✅ Staging deployment complete and verified healthy."
        puts "Do you want to proceed with production deployment? (y/n)"
        puts "=============================================================="
        puts "\n"

        response = STDIN.gets.chomp.downcase
        confirm_prod = response == "y"
      end

      if confirm_prod
        # Step 8: Deploy infrastructure to production
        TaskLogger.info("Deploying infrastructure to production...")
        Rake::Task["infra:deploy"].reenable
        Rake::Task["infra:deploy"].invoke("production")
        TaskLogger.info("✅ Production infrastructure deployed")

        # Step 9: Push container to production
        TaskLogger.info("Pushing container to production...")
        Rake::Task["deploy:build"].reenable
        Rake::Task["deploy:push"].reenable
        Rake::Task["deploy:build"].invoke("production")
        Rake::Task["deploy:push"].invoke("production")

        # Step 10: Update the registry for production
        TaskLogger.info("Updating registry for production...")
        Rake::Task["deploy:update_registry"].reenable
        Rake::Task["deploy:update_registry"].invoke("production")

        # Step 11: Health check on production
        TaskLogger.info("Checking production deployment health...")
        Rake::Task["deploy:health:check"].reenable
        Rake::Task["deploy:health:check"].invoke("production")

        # Step 12: Tag the release in git
        TaskLogger.info("Tagging release in git...")
        system("git tag -a #{version} -m 'Release #{version}'")
        system("git push origin #{version}")

        TaskLogger.info("✅ Release #{version} completed successfully!")
      else
        TaskLogger.info("❌ Production deployment skipped. Release process halted after staging.")
      end
    rescue => e
      TaskLogger.error("❌ Release process failed: #{e.message}")
      TaskLogger.error(e.backtrace.join("\n"))
      exit 1
    end
  end

  desc "Create a hotfix release (skips staging, deploys directly to production)"
  task :hotfix, [ :version ] do |t, args|
    version = args[:version]

    if version.nil? || version.empty?
      time_stamp = Time.now.strftime("%Y%m%d%H%M")
      version = "hotfix-#{time_stamp}"
      TaskLogger.info("No version specified, using generated version: #{version}")
    end

    begin
      TaskLogger.info("⚠️ Starting HOTFIX release process for version: #{version}")
      TaskLogger.info("⚠️ HOTFIX will deploy directly to production - USE WITH CAUTION")

      puts "\n"
      puts "=============================================================="
      puts "⚠️ WARNING: You are about to deploy a HOTFIX directly to PRODUCTION"
      puts "Are you sure you want to proceed? This skips staging verification. (y/n)"
      puts "=============================================================="
      puts "\n"

      response = STDIN.gets.chomp.downcase
      if response != "y"
        TaskLogger.info("❌ Hotfix cancelled.")
        exit 0
      end

      # Step 1: Verify prerequisites
      TaskLogger.info("Checking deployment prerequisites...")
      Rake::Task["deploy:check_prerequisites"].invoke

      # Step 2: Deploy infrastructure to production
      TaskLogger.info("Deploying infrastructure to production...")
      Rake::Task["infra:deploy"].invoke("production")

      # Step 3: Build and push the container
      TaskLogger.info("Building and pushing container...")
      Rake::Task["deploy:build"].invoke("production")
      Rake::Task["deploy:push"].invoke("production")

      # Step 4: Update the registry for production
      TaskLogger.info("Updating registry for production...")
      Rake::Task["deploy:update_registry"].invoke("production")

      # Step 5: Health check on production
      TaskLogger.info("Checking production deployment health...")
      Rake::Task["deploy:health:check"].invoke("production")

      # Step 6: Tag the hotfix in git
      TaskLogger.info("Tagging hotfix in git...")
      system("git tag -a #{version} -m 'Hotfix #{version}'")
      system("git push origin #{version}")

      TaskLogger.info("✅ Hotfix #{version} completed successfully!")
    rescue => e
      TaskLogger.error("❌ Hotfix process failed: #{e.message}")
      TaskLogger.error(e.backtrace.join("\n"))
      exit 1
    end
  end

  desc "Roll back to a previous version"
  task :rollback, [ :version, :env ] do |t, args|
    version = args[:version]
    env = args[:env] || "production"

    if version.nil? || version.empty?
      raise "You must specify a version to roll back to"
    end

    begin
      TaskLogger.info("⚠️ Rolling back #{env} to version: #{version}")

      puts "\n"
      puts "=============================================================="
      puts "⚠️ WARNING: Rolling back #{env} to version #{version}"
      puts "Are you sure you want to proceed? (y/n)"
      puts "=============================================================="
      puts "\n"

      response = STDIN.gets.chomp.downcase
      if response != "y"
        TaskLogger.info("❌ Rollback cancelled.")
        exit 0
      end

      # Step 1: Check out the specified version
      TaskLogger.info("Checking out version #{version}...")
      current_branch = `git rev-parse --abbrev-ref HEAD`.strip
      system("git checkout #{version}")

      # Step 2: Deploy infrastructure for the specified version
      TaskLogger.info("Deploying infrastructure for version #{version}...")
      Rake::Task["infra:deploy"].invoke(env)

      # Step 3: Build and push the container
      TaskLogger.info("Building and pushing container...")
      Rake::Task["deploy:build"].invoke(env)
      Rake::Task["deploy:push"].invoke(env)

      # Step 4: Update the registry
      TaskLogger.info("Updating registry...")
      Rake::Task["deploy:update_registry"].invoke(env)

      # Step 5: Health check
      TaskLogger.info("Checking deployment health...")
      Rake::Task["deploy:health:check"].invoke(env)

      # Step 6: Return to the original branch
      system("git checkout #{current_branch}")

      TaskLogger.info("✅ Rollback to #{version} completed successfully!")
    rescue => e
      # Try to restore the original branch if possible
      system("git checkout #{current_branch}") if defined?(current_branch) && !current_branch.nil?

      TaskLogger.error("❌ Rollback process failed: #{e.message}")
      TaskLogger.error(e.backtrace.join("\n"))
      exit 1
    end
  end
end
