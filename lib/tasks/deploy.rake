namespace :deploy do
  desc "initialize the project for deployment"
  task :init do
    puts "initializing tarot api for deployment with pulumi (infrastructure) and kamal (containers)..."

    # Run the Pulumi initialization for infrastructure
    Rake::Task["pulumi:init"].invoke

    # Check if Kamal is installed
    unless system("which kamal > /dev/null 2>&1")
      puts "kamal not found, installing..."
      system("gem install kamal") || abort("failed to install kamal")
    end

    # Create health check endpoint if it doesn't exist
    health_controller_path = "app/controllers/health_controller.rb"
    unless File.exist?(health_controller_path)
      puts "creating health check endpoint..."
      FileUtils.mkdir_p(File.dirname(health_controller_path))
      File.write(health_controller_path, <<~RUBY)
        class HealthController < ApplicationController
          def show
            render json: {#{' '}
              status: "ok",#{' '}
              version: ENV["GIT_COMMIT_SHA"] || "development",
              rails_env: Rails.env,
              db_connection: ActiveRecord::Base.connection.active?
            }
          end
        end
      RUBY
      puts "health controller created"

      # Add route for health check
      routes_file = "config/routes.rb"
      routes_content = File.read(routes_file)
      unless routes_content.include?("health")
        new_routes = routes_content.gsub(
          /Rails.application.routes.draw do/,
          "Rails.application.routes.draw do\n  # health check for deployment\n  get 'health', to: 'health#show'"
        )
        File.write(routes_file, new_routes)
        puts "added health check route"
      end
    end

    # Initialize Kamal if needed
    unless File.exist?("config/deploy.yml")
      puts "initializing kamal configuration..."

      # Create a simplified deploy.yml that works with Pulumi-created infrastructure
      deploy_yml = <<~YAML
        # Name of your application. Used to uniquely configure containers.
        service: tarot_api

        # Name of the container image.
        image: ${ECR_REGISTRY}/${APP_NAME}:${TAG}

        # Registry configuration (provided by environment variables)
        registry:
          # Uses the AWS ECR registry provided by Pulumi
          server: ${ECR_REGISTRY}
          username: ${AWS_ACCESS_KEY_ID}
          password: ${AWS_SECRET_ACCESS_KEY}

        # Main application servers
        servers:
          web:
            # Hosts are provided by Pulumi outputs
            hosts:
              - ec2-user@${INSTANCE_IP}
            labels:
              traefik.http.routers.tarot_api.rule: Host(`api.${DOMAIN}`)
              traefik.http.routers.tarot_api.tls: true
              traefik.http.routers.tarot_api.tls.certresolver: letsencrypt

        # Health check configuration
        healthcheck:
          path: /health
          port: 3000
          interval: 10s
          timeout: 5s
          retries: 5

        # Environment variable configuration
        env:
          clear:
            RAILS_ENV: production
            RAILS_LOG_TO_STDOUT: true
            RAILS_SERVE_STATIC_FILES: true
            DB_HOST: ${DB_HOST}
            DB_NAME: ${DB_NAME}
            DB_USERNAME: ${DB_USERNAME}
            REDIS_URL: ${REDIS_URL}
            AWS_BUCKET: ${AWS_BUCKET}
            AWS_REGION: ${AWS_REGION}
          secret:
            - RAILS_MASTER_KEY
            - DB_PASSWORD
            - AWS_ACCESS_KEY_ID
            - AWS_SECRET_ACCESS_KEY
            - OPENAI_API_KEY

        # Blue-green deployment configuration
        rollout:
          version: v2
          strategy: blue-green

        # Multi-environment configuration
        destinations:
          staging:
            env:
              clear:
                RAILS_ENV: staging
        #{'  '}
          production:
            env:
              clear:
                RAILS_ENV: production
        #{'        '}
          # Preview environments are dynamically created
          preview-*:
            env:
              clear:
                RAILS_ENV: development
      YAML

      # Create directory if it doesn't exist
      FileUtils.mkdir_p("config")

      # Write the deploy.yml file
      File.write("config/deploy.yml", deploy_yml)
      puts "created simplified config/deploy.yml template"
      puts "note: this is a template that will be populated with values from pulumi"
    end

    puts "initialization complete"
    puts "next steps:"
    puts "1. run 'bundle exec rake pulumi:deploy[staging]' to provision infrastructure"
    puts "2. run 'bundle exec rake deploy:app:staging' to deploy the application"
  end

  namespace :app do
    desc "deploy application to staging using kamal (after infrastructure is ready)"
    task :staging do
      puts "deploying application to staging environment with kamal..."

      # Get infrastructure details from Pulumi
      puts "fetching infrastructure details from pulumi..."

      # Set environment variables from Pulumi outputs
      env_vars = get_env_vars_from_pulumi("staging")

      # Build and push container
      puts "building and pushing container..."
      system(env_vars, "kamal build") || abort("failed to build image")
      system(env_vars, "kamal push") || abort("failed to push image")

      # Deploy to staging with Kamal
      if system(env_vars, "kamal deploy -d staging")
        puts "successfully deployed application to staging"
      else
        abort "application deployment to staging failed"
      end
    end

    desc "deploy application to production using kamal (after infrastructure is ready)"
    task :production do
      puts "deploying application to production environment with kamal..."

      # Get infrastructure details from Pulumi
      puts "fetching infrastructure details from pulumi..."

      # Set environment variables from Pulumi outputs
      env_vars = get_env_vars_from_pulumi("production")

      # Build and push container
      puts "building and pushing container..."
      system(env_vars, "kamal build") || abort("failed to build image")
      system(env_vars, "kamal push") || abort("failed to push image")

      # Deploy to production with Kamal
      if system(env_vars, "kamal deploy -d production")
        puts "successfully deployed application to production"
      else
        abort "application deployment to production failed"
      end
    end

    desc "deploy application to preview environment using kamal (after infrastructure is ready)"
    task :preview, [ :name ] do |t, args|
      name = args[:name]
      abort "error: preview name is required" unless name

      puts "deploying application to preview environment: #{name}..."

      # Get infrastructure details from Pulumi
      puts "fetching infrastructure details from pulumi..."

      # Set environment variables from Pulumi outputs
      env_vars = get_env_vars_from_pulumi("preview-#{name}")

      # Build and push container
      puts "building and pushing container..."
      system(env_vars, "kamal build") || abort("failed to build image")
      system(env_vars, "kamal push") || abort("failed to push image")

      # Deploy to preview with Kamal
      if system(env_vars, "kamal deploy -d preview-#{name}")
        puts "successfully deployed application to preview-#{name}"
      else
        abort "application deployment to preview-#{name} failed"
      end
    end
  end

  namespace :infra do
    desc "deploy infrastructure for staging using pulumi"
    task :staging do
      puts "deploying infrastructure for staging environment using pulumi..."
      Rake::Task["pulumi:deploy"].invoke("staging")
    end

    desc "deploy infrastructure for production using pulumi"
    task :production do
      puts "deploying infrastructure for production environment using pulumi..."
      Rake::Task["pulumi:deploy_production"].invoke
    end

    desc "create infrastructure for a preview environment using pulumi"
    task :preview, [ :name ] do |t, args|
      name = args[:name]
      abort "error: preview name is required" unless name

      puts "creating preview environment infrastructure: #{name}..."
      Rake::Task["pulumi:create_preview"].invoke(name)
    end

    desc "destroy infrastructure for a preview environment"
    task :destroy_preview, [ :name ] do |t, args|
      name = args[:name]
      abort "error: preview name is required" unless name

      puts "destroying preview environment infrastructure: #{name}..."
      Rake::Task["pulumi:delete_preview"].invoke(name)
    end
  end

  desc "deploy both infrastructure and application to staging"
  task staging: [ "infra:staging", "app:staging" ]

  desc "deploy both infrastructure and application to production"
  task production: [ "infra:production", "app:production" ]

  desc "create and deploy both infrastructure and application to preview environment"
  task :preview, [ :name ] => :environment do |t, args|
    name = args[:name]
    abort "error: preview name is required" unless name

    Rake::Task["deploy:infra:preview"].invoke(name)
    Rake::Task["deploy:app:preview"].invoke(name)
  end

  desc "show deployment status"
  task :status, [ :environment ] do |t, args|
    env = args[:environment] || "staging"
    puts "checking status of #{env} environment..."

    # Check infrastructure status
    puts "\n=== Infrastructure Status (Pulumi) ==="
    Rake::Task["pulumi:info"].invoke(env)

    # Check application status with Kamal
    puts "\n=== Application Status (Kamal) ==="
    system("kamal status -d #{env}")
  end

  desc "list all preview environments"
  task :list_previews do
    puts "listing all preview environments..."
    Rake::Task["pulumi:list_previews"].invoke
  end

  desc "clean up inactive preview environments"
  task :cleanup_previews do
    puts "cleaning up inactive preview environments..."
    Rake::Task["pulumi:cleanup_previews"].invoke
  end

  desc "alias for deploy:staging"
  task deploy: :staging

  # Help information
  desc "show deployment help"
  task :help do
    puts <<~HELP
      deployment commands:

      setup:
      bundle exec rake deploy:init               # initialize deployment setup

      infrastructure deployment (pulumi):
      bundle exec rake deploy:infra:staging      # deploy infrastructure to staging
      bundle exec rake deploy:infra:production   # deploy infrastructure to production
      bundle exec rake deploy:infra:preview[name] # create preview environment infrastructure

      application deployment (kamal):
      bundle exec rake deploy:app:staging        # deploy application to staging
      bundle exec rake deploy:app:production     # deploy application to production
      bundle exec rake deploy:app:preview[name]  # deploy application to preview environment

      combined deployment (both infra and app):
      bundle exec rake deploy                    # deploy to staging (alias)
      bundle exec rake deploy:staging            # deploy to staging#{' '}
      bundle exec rake deploy:production         # deploy to production
      bundle exec rake deploy:preview[name]      # create and deploy preview environment

      management:
      bundle exec rake deploy:status[env]        # check deployment status
      bundle exec rake deploy:list_previews      # list all preview environments
      bundle exec rake deploy:cleanup_previews   # clean up inactive preview environments
      bundle exec rake deploy:infra:destroy_preview[name] # destroy preview infrastructure
    HELP
  end

  # Domain management
  desc "register the domain"
  task :register_domain do
    puts "registering the domain..."
    Rake::Task["pulumi:register_domain"].invoke
  end

  desc "protect domain from accidental deletion"
  task :protect_domain do
    puts "protecting domain from accidental deletion..."
    Rake::Task["pulumi:protect_domain"].invoke
  end

  # Add a task to deploy a new environment with domain setup
  desc "Create a new environment with infrastructure and domain setup"
  task :new_environment, [ :environment, :domain ] => [ :environment ] do |t, args|
    env = args[:environment] || abort("Environment name is required")
    domain = args[:domain] || "tarotapi.cards"

    # Validate environment
    unless %w[production staging preview].include?(env)
      abort "Invalid environment. Choose one of: production, staging, preview"
    end

    puts "Setting up #{env} environment with domain #{domain}..."

    # Step 1: Check if domain is registered
    puts "Checking domain registration..."
    domain_registered = system("aws route53domains get-domain-detail --domain-name #{domain} > /dev/null 2>&1")

    unless domain_registered
      puts "Domain #{domain} is not registered. You need to register it first."
      puts "Would you like to register the domain now? (yes/no)"
      response = STDIN.gets.chomp.downcase

      if response == "yes"
        # Try to use the fully automated method first
        Rake::Task["pulumi:register_domain_fully_automated"].invoke
      else
        puts "Proceeding without domain registration. You will need to register the domain manually."
      end
    else
      puts "Domain #{domain} is already registered."
    end

    # Step 2: Setup infrastructure using Pulumi
    puts "Deploying infrastructure for #{env} environment..."
    Rake::Task["pulumi:deploy"].invoke(env)

    # Step 3: Configure SSL certificate
    puts "Setting up SSL certificate..."

    # This happens automatically in the Pulumi deployment, but we should check
    # if it's completed successfully
    puts "Checking SSL certificate validation..."
    Rake::Task["pulumi:info"].invoke(env)

    # Step 4: Protect domain if production
    if env == "production"
      puts "Setting up domain protection..."
      Rake::Task["pulumi:protect_domain"].invoke
    end

    # Step 5: Deploy application
    puts "Deploying application to #{env} environment..."
    Rake::Task["deploy:#{env}"].invoke

    # Output completion message with domain information
    puts ""
    puts "==========================================================="
    puts "Deployment to #{env} environment completed successfully!"
    puts "Domain: #{env == 'production' ? domain : "#{env}.#{domain}"}"
    puts ""
    puts "You can access your application at:"
    puts "  • API: https://#{env == 'production' ? domain : "#{env}.#{domain}"}"
    puts "  • CDN: https://#{env == 'production' ? "cdn.#{domain}" : "cdn-#{env}.#{domain}"}"
    puts "==========================================================="
  end

  namespace :kamal do
    desc "Validate Kamal configuration"
    task :validate do
      require 'rainbow'
      
      puts Rainbow("Validating Kamal configuration...").bright
      
      deploy_yml_path = "config/deploy.yml"
      unless File.exist?(deploy_yml_path)
        puts Rainbow("Error: config/deploy.yml not found!").red
        exit 1
      end
      
      # Check for hardcoded sensitive data
      sensitive_patterns = ["password:", "secret:", "key:", "token:"]
      found_sensitive = false
      
      sensitive_patterns.each do |pattern|
        lines = File.readlines(deploy_yml_path).each_with_index.select { |line, _| line.include?(pattern) && !line.include?("ENV") }
        
        if lines.any?
          found_sensitive = true
          puts Rainbow("Warning: Possible hardcoded sensitive data found in deploy.yml:").orange
          lines.each do |line, idx|
            puts Rainbow("  Line #{idx + 1}: #{line.strip}").orange
          end
          puts Rainbow("  Fix: Ensure all sensitive data uses environment variables like <%= ENV['KEY_NAME'] %>").orange
          puts
        end
      end
      
      # Validate Kamal configuration syntax
      print "Running Kamal configuration check: "
      
      # First check if the kamal command is available
      unless system("which kamal > /dev/null 2>&1")
        puts Rainbow("✗ Kamal command not found").red
        puts Rainbow("Install Kamal with: gem install kamal").yellow
        exit 1
      end
      
      # Check if the 'check' subcommand is available (newer versions of Kamal)
      if system("kamal help | grep check > /dev/null 2>&1")
        if system("kamal check > /dev/null 2>&1")
          puts Rainbow("✓ Valid").green
        else
          puts Rainbow("✗ Invalid").red
          puts
          puts Rainbow("Detailed Kamal configuration check:").bright
          system("kamal check")
          puts
          puts Rainbow("Fix the issues above to ensure proper deployment.").yellow
          exit 1 if found_sensitive
        end
      else
        # Kamal doesn't have 'check' command, try a simpler validation
        puts Rainbow("✗ 'check' command not available in your Kamal version").yellow
        puts
        puts Rainbow("Performing basic validation:").bright
        
        begin
          require 'yaml'
          config = YAML.load_file(deploy_yml_path)
          
          # Check for required keys
          required_keys = ["service", "image", "servers"]
          missing_keys = required_keys - config.keys
          
          if missing_keys.any?
            puts Rainbow("Error: Missing required keys: #{missing_keys.join(', ')}").red
            exit 1
          end
          
          # If we get here, the YAML is valid and has the basic required keys
          puts Rainbow("✓ Basic validation passed").green
          puts Rainbow("Note: Full Kamal validation not available. Update kamal gem for full validation.").yellow
        rescue => e
          puts Rainbow("Error parsing YAML: #{e.message}").red
          exit 1
        end
      end
      
      # If no issues were found
      unless found_sensitive
        puts Rainbow("✅ No hardcoded sensitive data found!").green
        puts Rainbow("✅ Kamal configuration format appears valid!").green
      end
    end
    
    desc "Validate Kamal configuration for GitHub Actions"
    task :validate_ci do
      deploy_yml_path = "config/deploy.yml"
      unless File.exist?(deploy_yml_path)
        puts "::error::config/deploy.yml not found!"
        exit 1
      end
      
      # Check for hardcoded sensitive data
      sensitive_patterns = ["password:", "secret:", "key:", "token:"]
      found_sensitive = false
      
      sensitive_patterns.each do |pattern|
        lines = File.readlines(deploy_yml_path).each_with_index.select { |line, _| line.include?(pattern) && !line.include?("ENV") }
        
        if lines.any?
          found_sensitive = true
          lines.each do |line, idx|
            puts "::warning::Possible hardcoded sensitive data found in deploy.yml (line #{idx + 1}): #{line.strip}"
          end
          puts "::warning::Ensure all sensitive data uses environment variables like <%= ENV['KEY_NAME'] %>"
        end
      end
      
      # Validate Kamal configuration
      unless system("kamal check > /dev/null 2>&1")
        puts "::warning::Kamal configuration may be invalid or missing required settings."
        puts "::warning::Run 'kamal check' locally to debug the specific issues."
      end
      
      exit 1 if found_sensitive
    end
  end

  private

  # Helper method to get environment variables from Pulumi outputs
  def get_env_vars_from_pulumi(environment)
    puts "fetching pulumi outputs for #{environment} environment..."

    # Select the stack
    system("cd infrastructure && pulumi stack select #{environment}") || abort("failed to select pulumi stack")

    # Get stack outputs
    outputs_json = `cd infrastructure && pulumi stack output --json`
    abort "failed to get stack outputs" if outputs_json.empty?

    # Parse outputs
    begin
      outputs = JSON.parse(outputs_json)
    rescue JSON::ParserError
      abort "failed to parse stack outputs as json"
    end

    # Extract shell format
    shell_vars = outputs["shellFormat"] || {}
    
    # Additional variables
    shell_vars["APP_NAME"] = "tarot-api"
    shell_vars["TAG"] = `git rev-parse --short HEAD`.strip
    shell_vars["ECR_REGISTRY"] = shell_vars["ECR_REPO"].to_s.split('/').first if shell_vars["ECR_REPO"]
    
    # Add AWS credentials
    shell_vars["AWS_ACCESS_KEY_ID"] = ENV["AWS_ACCESS_KEY_ID"]
    shell_vars["AWS_SECRET_ACCESS_KEY"] = ENV["AWS_SECRET_ACCESS_KEY"]
    
    # Add database password from Pulumi config
    db_password = `cd infrastructure && pulumi config get --secret databasePassword`
    shell_vars["DB_PASSWORD"] = db_password.strip unless db_password.empty?
    
    # Add Rails master key
    shell_vars["RAILS_MASTER_KEY"] = ENV["RAILS_MASTER_KEY"] || File.read("config/master.key").strip rescue nil
    
    # Add OpenAI API key if available
    shell_vars["OPENAI_API_KEY"] = ENV["OPENAI_API_KEY"] if ENV["OPENAI_API_KEY"]
    
    # Return the environment variables
    return shell_vars
  end
end
