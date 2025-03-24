# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require_relative "config/application"

Rails.application.load_tasks

# Check if running inside a Docker container
def inside_docker?
  File.exist?('/.dockerenv')
end

# Add a wrapper to redirect all non-Docker tasks to the Docker container
task :default do
  if !inside_docker? && ARGV.size > 0 && ARGV[0] != 'dev:up' &&
     ARGV[0] != 'dev:down' && !ARGV[0].start_with?('docker:')
    sh "docker compose exec api bundle exec rake #{ARGV.join(' ')}"
    exit 0
  end
end

# Add a special task to set the development container registry
task :set_dev_registry do
  ENV["CONTAINER_REGISTRY"] ||= "ghcr.io/#{ENV['GITHUB_REPOSITORY_OWNER'] || 'abdul-hamid-achik'}/tarotapi"
  puts "Using container registry: #{ENV['CONTAINER_REGISTRY']}"
end
