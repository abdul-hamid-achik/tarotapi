namespace :deploy do
  desc "initialize the project for deployment"
  task :init do
    TaskLogger.with_task_logging("deploy:init") do
      TaskLogger.info("Initializing tarot api for deployment with pulumi (infrastructure) and kamal (containers)...")

      # Run the Pulumi initialization for infrastructure
      Rake::Task["pulumi:init"].invoke

      # Check if Kamal is installed
      unless system("which kamal > /dev/null 2>&1")
        TaskLogger.info("Kamal not found, installing...")
        system("gem install kamal") || abort("Failed to install kamal")
      end

      # Create health check endpoint if it doesn't exist
      health_controller_path = "app/controllers/health_controller.rb"
      unless File.exist?(health_controller_path)
        TaskLogger.info("Creating health check endpoint...")
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
        TaskLogger.info("Health controller created")

        # Add route for health check
        routes_file = "config/routes.rb"
        routes_content = File.read(routes_file)
        unless routes_content.include?("health")
          new_routes = routes_content.gsub(
            /Rails.application.routes.draw do/,
            "Rails.application.routes.draw do\n  # health check for deployment\n  get 'health', to: 'health#show'"
          )
          File.write(routes_file, new_routes)
          TaskLogger.info("Added health check route")
        end
      end

      # Initialize Kamal if needed
      unless File.exist?("config/deploy.yml")
        TaskLogger.info("Initializing kamal configuration...")

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
            production:
              env:
                clear:
                  RAILS_ENV: production
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
        TaskLogger.info("Created simplified config/deploy.yml template")
        TaskLogger.info("Note: this is a template that will be populated with values from pulumi")
      end

      TaskLogger.info("Initialization complete")
      TaskLogger.info("Next steps:")
      TaskLogger.info("1. run 'bundle exec rake pulumi:deploy[staging]' to provision infrastructure")
      TaskLogger.info("2. run 'bundle exec rake deploy:app:staging' to deploy the application")
    end
  end
  # Rest of the code remains the same...
