require "dotenv"
require "semantic_logger"
require_relative "../task_logger"

namespace :deploy do
  desc "Deploy the application with zero downtime"
  task :production do
    TaskLogger.info("Starting zero-downtime deployment to production...")
    Rake::Task["deploy:check_prerequisites"].invoke
    Rake::Task["deploy:build"].invoke
    Rake::Task["deploy:push"].invoke
    Rake::Task["deploy:update_registry"].invoke
    TaskLogger.info("Deployment completed successfully!")
  end

  desc "Deploy to staging environment"
  task :staging do
    TaskLogger.info("Starting deployment to staging...")
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
    
    # Raise error if still not set
    raise "#{cluster_var_name} not set" if cluster.nil?
    raise "#{service_var_name} not set" if service.nil?

    TaskLogger.info("Updating container registry in #{env}...")
    # Use --no-cli-pager to avoid opening vim and pipe through a JSON formatter
    json_output = `aws ecs update-service --no-cli-pager --cluster #{cluster} --service #{service} --force-new-deployment`
    
    begin
      # Try to parse and prettify the JSON
      require 'json'
      parsed_json = JSON.parse(json_output)
      pretty_json = JSON.pretty_generate(parsed_json)
      
      # Print the prettified JSON with some formatting
      puts "\n----- Service Update Result -----"
      puts pretty_json
      puts "--------------------------------\n"
    rescue => e
      # If JSON parsing fails, just output the raw result
      puts json_output
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
