namespace :api do
  desc "generate swagger documentation"
  task :docs do
    puts "generating api documentation..."

    if system("RAILS_ENV=test bundle exec rake rswag:specs:swaggerize")
      puts "api documentation generated successfully"
    else
      puts "failed to generate api documentation"
      exit 1
    end
  end

  desc "publish api documentation to s3"
  task publish: [ :docs ] do
    puts "publishing api documentation to s3..."

    # Check for required environment variables
    unless ENV["AWS_ACCESS_KEY_ID"] && ENV["AWS_SECRET_ACCESS_KEY"] && ENV["AWS_S3_BUCKET"]
      abort "missing required AWS environment variables (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_S3_BUCKET)"
    end

    # Upload swagger files to S3
    swagger_dir = "swagger"
    s3_prefix = "api-docs"

    cmd = "aws s3 sync #{swagger_dir} s3://#{ENV['AWS_S3_BUCKET']}/#{s3_prefix} --acl public-read"

    if system(cmd)
      puts "api documentation published to s3://#{ENV['AWS_S3_BUCKET']}/#{s3_prefix}"

      # Print URL to documentation
      region = ENV["AWS_DEFAULT_REGION"] || "us-west-2"
      puts "access documentation at: https://#{ENV['AWS_S3_BUCKET']}.s3.#{region}.amazonaws.com/#{s3_prefix}/v1/swagger.json"
    else
      puts "failed to publish api documentation"
      exit 1
    end
  end

  desc "run integration tests against a deployed api"
  task :test_integration, [ :base_url ] => :environment do |_, args|
    base_url = args[:base_url] || ENV["API_BASE_URL"] || "http://localhost:3000"

    puts "running integration tests against #{base_url}..."

    # Set environment variable for tests
    ENV["API_BASE_URL"] = base_url

    # Run the integration tests
    if system("bundle exec cucumber features/api")
      puts "integration tests passed"
    else
      puts "integration tests failed"
      exit 1
    end
  end

  desc "validate api responses against swagger schema"
  task validate: :environment do
    puts "validating api responses against swagger schema..."

    # Build the API validation command
    if system("bundle exec rake rswag:specs:swaggerize")
      puts "api schema validation passed"
    else
      puts "api schema validation failed"
      exit 1
    end
  end

  namespace :version do
    desc "create a new api version"
    task :create, [ :version ] => :environment do |_, args|
      version = args[:version] || abort("version required (e.g., v2)")

      puts "creating new api version: #{version}..."

      # Create directory structure
      controllers_dir = "app/controllers/api/#{version}"
      serializers_dir = "app/serializers/api/#{version}"
      swagger_dir = "swagger/#{version}"
      spec_dir = "spec/requests/api/#{version}"
      route_file = "config/routes/api_#{version}.rb"

      # Create directories
      FileUtils.mkdir_p(controllers_dir)
      FileUtils.mkdir_p(serializers_dir)
      FileUtils.mkdir_p(swagger_dir)
      FileUtils.mkdir_p(spec_dir)

      # Create base controller
      base_controller = File.join(controllers_dir, "base_controller.rb")
      File.open(base_controller, "w") do |f|
        f.puts "class Api::#{version.upcase}::BaseController < ApplicationController"
        f.puts "  # Add version-specific controller logic here"
        f.puts "end"
      end

      # Create routes file
      File.open(route_file, "w") do |f|
        f.puts "# API #{version.upcase} routes"
        f.puts "namespace :api do"
        f.puts "  namespace :#{version} do"
        f.puts "    # Add your #{version} routes here"
        f.puts "  end"
        f.puts "end"
      end

      # Update main routes file to include new version
      routes_file = "config/routes.rb"
      routes_content = File.read(routes_file)

      unless routes_content.include?("draw \"api_#{version}\"")
        # Find the Rails.application.routes.draw block
        if routes_content =~ /(Rails\.application\.routes\.draw do.+?end)/m
          match = $1
          # Add the new version to the routes
          updated_routes = match.sub(/(\s*end\s*\Z)/, "  draw \"api_#{version}\"\n\\1")
          # Replace the old routes block with the updated one
          File.write(routes_file, routes_content.sub(match, updated_routes))
        end
      end

      puts "created new api version: #{version}"
      puts "directories created:"
      puts "  - #{controllers_dir}"
      puts "  - #{serializers_dir}"
      puts "  - #{swagger_dir}"
      puts "  - #{spec_dir}"
      puts "files created:"
      puts "  - #{base_controller}"
      puts "  - #{route_file}"
      puts "updated:"
      puts "  - #{routes_file}"
    end
  end
end
