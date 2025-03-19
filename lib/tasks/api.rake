namespace :api do
  desc "generate api documentation"
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

    # Upload spec files to S3
    spec_dir = "public/api"
    s3_prefix = "api-docs"

    cmd = "aws s3 sync #{spec_dir} s3://#{ENV['AWS_S3_BUCKET']}/#{s3_prefix} --acl public-read"

    if system(cmd)
      puts "api documentation published to s3://#{ENV['AWS_S3_BUCKET']}/#{s3_prefix}"

      # Print URL to documentation
      region = ENV["AWS_DEFAULT_REGION"] || "us-west-2"
      puts "access documentation at: https://#{ENV['AWS_S3_BUCKET']}.s3.#{region}.amazonaws.com/#{s3_prefix}/v1/spec.json"
    else
      puts "failed to publish api documentation"
      exit 1
    end
  end

  desc "setup redoc ui for api documentation"
  task :setup_redoc do
    puts "setting up redoc ui for api documentation..."

    # Create public/docs directory if it doesn't exist
    FileUtils.mkdir_p("public/docs")

    # Create index.html with ReDoc
    redoc_html = <<~HTML
      <!DOCTYPE html>
      <html>
        <head>
          <title>tarot api documentation</title>
          <meta charset="utf-8"/>
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <link href="https://fonts.googleapis.com/css?family=Montserrat:300,400,700|Roboto:300,400,700" rel="stylesheet">
          <style>
            body {
              margin: 0;
              padding: 0;
            }
          </style>
        </head>
        <body>
          <redoc spec-url="/api-docs/v1/spec.yaml"></redoc>
          <script src="https://cdn.redoc.ly/redoc/latest/bundles/redoc.standalone.js"></script>
        </body>
      </html>
    HTML

    File.write("public/docs/index.html", redoc_html)

    puts "redoc ui setup complete"
    puts "add the following to your routes.rb to serve the docs:"
    puts
    puts "  # redoc api documentation"
    puts '  get "/api-docs", to: redirect("/docs/index.html")'
    puts
    puts "ensure your spec files are available at /api-docs/v1/spec.yaml"
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

  desc "validate api responses against api schema"
  task :validate do
    puts "validating api responses against api schema..."

    # Run the RSpec tests with RSwag
    if system("bundle exec rake rswag:specs:swaggerize")
      puts "api schema validation passed"
    else
      puts "api schema validation failed"
      exit 1
    end
  end

  desc "generate api documentation for specific version"
  task :generate_docs, [ :version ] => :environment do |_, args|
    version = args[:version] || "v1"
    spec_dir = "public/api/#{version}"
    puts "generating api documentation for version #{version}..."

    # Create directory if it doesn't exist
    FileUtils.mkdir_p(spec_dir)

    # Generate documentation
    if system("RAILS_ENV=test VERSION=#{version} bundle exec rake rswag:specs:swaggerize")
      puts "api documentation for version #{version} generated successfully"
      puts "documentation available in:"
      puts "  - #{spec_dir}"
    else
      puts "failed to generate api documentation for version #{version}"
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
      spec_dir = "public/api/#{version}"
      test_dir = "spec/requests/api/#{version}"
      route_file = "config/routes/api_#{version}.rb"

      # Create directories
      FileUtils.mkdir_p(controllers_dir)
      FileUtils.mkdir_p(serializers_dir)
      FileUtils.mkdir_p(spec_dir)
      FileUtils.mkdir_p(test_dir)

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
      puts "  - #{spec_dir}"
      puts "  - #{test_dir}"
      puts "files created:"
      puts "  - #{base_controller}"
      puts "  - #{route_file}"
      puts "updated:"
      puts "  - #{routes_file}"
    end
  end
end
