namespace :api do
  desc "generate and validate api documentation"
  task :docs do
    TaskLogger.info("generating api documentation...")

    if system("RAILS_ENV=test bundle exec rake rswag:specs:swaggerize")
      TaskLogger.info("api documentation generated successfully")

      # Validate the generated documentation
      Rake::Task["api:validate"].invoke
    else
      TaskLogger.error("failed to generate api documentation")
      exit 1
    end
  end

  desc "validate openapi specification"
  task :validate do
    require "yaml"
    require "openapi_parser"

    TaskLogger.info("validating openapi specification...")

    spec_file = Rails.root.join("public/api/v1/spec.yaml")

    begin
      spec = YAML.load_file(spec_file)
      config = OpenAPIParser::Config.new(
        strict_reference_validation: false,
        validate_required_security_schemes: false
      )
      OpenAPIParser.parse(spec, config)

      # Additional custom validations
      validate_security_schemes(spec)
      validate_error_responses(spec)
      validate_rate_limiting(spec)
      validate_examples(spec)

      TaskLogger.info("openapi specification is valid!")
    rescue OpenAPIParser::OpenAPIError => e
      TaskLogger.error("openapi specification validation failed:")
      TaskLogger.error(e.message)
      exit 1
    end
  end

  desc "setup redoc ui for api documentation"
  task :setup_redoc do
    TaskLogger.info("setting up redoc ui for api documentation...")

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
          <redoc spec-url="/api/v1/spec.yaml" theme="dark"></redoc>
          <script src="https://cdn.redoc.ly/redoc/latest/bundles/redoc.standalone.js"></script>
        </body>
      </html>
    HTML

    File.write("public/docs/index.html", redoc_html)

    TaskLogger.info("redoc ui setup complete")
    TaskLogger.info("documentation will be available at /docs")
  end

  desc "run integration tests against a deployed api"
  task :test, [ :base_url ] => :environment do |_, args|
    base_url = args[:base_url] || ENV["API_BASE_URL"] || "http://localhost:3000"

    TaskLogger.info("running integration tests against #{base_url}...")

    ENV["API_BASE_URL"] = base_url

    if system("bundle exec cucumber features/api")
      TaskLogger.info("integration tests passed")
    else
      TaskLogger.error("integration tests failed")
      exit 1
    end
  end

  desc "publish api documentation to s3"
  task publish: [ :docs ] do
    TaskLogger.info("publishing api documentation to s3...")

    # Check for required environment variables
    unless ENV["AWS_ACCESS_KEY_ID"] && ENV["AWS_SECRET_ACCESS_KEY"] && ENV["AWS_S3_BUCKET"]
      abort "missing required AWS environment variables (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_S3_BUCKET)"
    end

    # Upload spec files to S3
    spec_dir = "public/api"
    s3_prefix = "api-docs"

    cmd = "aws s3 sync #{spec_dir} s3://#{ENV['AWS_S3_BUCKET']}/#{s3_prefix} --acl public-read"

    if system(cmd)
      TaskLogger.info("api documentation published to s3://#{ENV['AWS_S3_BUCKET']}/#{s3_prefix}")

      # Print URL to documentation
      region = ENV["AWS_DEFAULT_REGION"] || "mx-central-1"
      TaskLogger.info("access documentation at: https://#{ENV['AWS_S3_BUCKET']}.s3.#{region}.amazonaws.com/#{s3_prefix}/v1/spec.json")
    else
      TaskLogger.error("failed to publish api documentation")
      exit 1
    end
  end

  desc "generate api documentation for specific version"
  task :generate_docs, [ :version ] => :environment do |_, args|
    version = args[:version] || "v1"
    spec_dir = "public/api/#{version}"
    TaskLogger.info("generating api documentation for version #{version}...")

    # Create directory if it doesn't exist
    FileUtils.mkdir_p(spec_dir)

    # Generate documentation
    if system("RAILS_ENV=test VERSION=#{version} bundle exec rake rswag:specs:swaggerize")
      TaskLogger.info("api documentation for version #{version} generated successfully")
      TaskLogger.info("documentation available in:")
      TaskLogger.info("  - #{spec_dir}")
    else
      TaskLogger.error("failed to generate api documentation for version #{version}")
      exit 1
    end
  end

  # Standalone task that doesn't require the Rails environment
  desc "validate openapi specification without requiring the database"
  task :validate_spec_standalone do
    require "yaml"
    require "openapi_parser"

    TaskLogger.info("validating openapi specification (standalone mode)...")

    spec_file = File.join(Dir.pwd, "public/api/v1/spec.yaml")
    unless File.exist?(spec_file)
      TaskLogger.error("spec file not found at #{spec_file}")
      exit 1
    end

    begin
      spec = YAML.load_file(spec_file)
      # Configure the parser to be more lenient
      config = OpenAPIParser::Config.new(
        strict_reference_validation: false,
        validate_required_security_schemes: false
      )
      OpenAPIParser.parse(spec, config)

      TaskLogger.info("openapi specification is valid!")
    rescue OpenAPIParser::OpenAPIError => e
      TaskLogger.error("openapi specification validation failed:")
      TaskLogger.error(e.message)
      exit 1
    end
  end

  namespace :version do
    desc "create a new api version"
    task :create, [ :version ] => :environment do |_, args|
      version = args[:version] || abort("version required (e.g., v2)")

      TaskLogger.info("creating new api version: #{version}...")

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
        if routes_content =~ /(Rails\.application\.routes\.draw do.+?end)/m
          match = $1
          updated_routes = match.sub(/(\s*end\s*\Z)/, "  draw \"api_#{version}\"\n\\1")
          File.write(routes_file, routes_content.sub(match, updated_routes))
        end
      end

      TaskLogger.info("created new api version: #{version}")
      TaskLogger.info("directories created:")
      TaskLogger.info("  - #{controllers_dir}")
      TaskLogger.info("  - #{serializers_dir}")
      TaskLogger.info("  - #{spec_dir}")
      TaskLogger.info("  - #{test_dir}")
      TaskLogger.info("files created:")
      TaskLogger.info("  - #{base_controller}")
      TaskLogger.info("  - #{route_file}")
      TaskLogger.info("updated:")
      TaskLogger.info("  - #{routes_file}")
    end
  end

  private

  def validate_security_schemes(spec)
    return unless spec["security"] && spec["security"].any? { |s| s.key?("bearerAuth") }

    unless spec["components"] &&
           spec["components"]["securitySchemes"] &&
           spec["components"]["securitySchemes"]["bearerAuth"]
      raise "Missing security scheme definition for bearerAuth"
    end
  end

  def validate_error_responses(spec)
    spec["paths"].each do |path, methods|
      methods.each do |method, details|
        next if %w[parameters summary tags description].include?(method)

        responses = details["responses"] || {}
        unless responses.keys.any? { |k| k.start_with?("4") }
          raise "Endpoint #{method.upcase} #{path} is missing error responses"
        end
      end
    end
  end

  def validate_rate_limiting(spec)
    unless spec["info"]["description"].include?("rate limit")
      raise "API description should include rate limiting information"
    end

    spec["paths"].each do |path, methods|
      methods.each do |method, details|
        next if %w[parameters summary tags description].include?(method)

        success_responses = (details["responses"] || {}).select { |k, _| k.start_with?("2") }
        success_responses.each do |_, response|
          unless response["headers"] &&
                 response["headers"]["X-RateLimit-Limit"] &&
                 response["headers"]["X-RateLimit-Remaining"] &&
                 response["headers"]["X-RateLimit-Reset"]
            raise "Success response for #{method.upcase} #{path} is missing rate limit headers"
          end
        end
      end
    end
  end

  def validate_examples(spec)
    spec["paths"].each do |path, methods|
      methods.each do |method, details|
        next if %w[parameters summary tags description].include?(method)

        if details["requestBody"]
          schema = details["requestBody"]["content"]["application/json"]["schema"]
          validate_schema_examples(schema, "Request body for #{method.upcase} #{path}")
        end

        (details["responses"] || {}).each do |code, response|
          next unless response["content"]
          schema = response["content"]["application/json"]["schema"]
          validate_schema_examples(schema, "Response #{code} for #{method.upcase} #{path}")
        end
      end
    end
  end

  def validate_schema_examples(schema, context)
    return if schema["$ref"] # Skip referenced schemas

    if schema["type"] == "object"
      unless schema["example"] || schema["examples"] ||
             (schema["properties"] && schema["properties"].values.all? { |p| p["example"] })
        raise "#{context} is missing examples"
      end
    end
  end
end
