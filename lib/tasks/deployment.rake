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
    registry = ENV["CONTAINER_REGISTRY"] || raise("CONTAINER_REGISTRY not set")

    TaskLogger.info("Pushing container image to #{registry}...")
    system("docker tag tarot-api:#{env} #{registry}/tarot-api:#{env}")
    system("docker push #{registry}/tarot-api:#{env}")
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
    cluster = ENV["CLUSTER_NAME_#{env.upcase}"] || raise("CLUSTER_NAME_#{env.upcase} not set")
    service = ENV["SERVICE_NAME_#{env.upcase}"] || raise("SERVICE_NAME_#{env.upcase} not set")

    TaskLogger.info("Updating container registry in #{env}...")
    system("aws ecs update-service --cluster #{cluster} --service #{service} --force-new-deployment")
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
