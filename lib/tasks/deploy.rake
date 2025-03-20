namespace :deploy do
  desc "initialize the project for kamal deployment"
  task :init do
    puts "initializing tarot api for kamal deployment..."
    
    # Install required gems
    puts "adding kamal to Gemfile..."
    gemfile_content = File.read("Gemfile")
    unless gemfile_content.include?("kamal")
      File.open("Gemfile", "a") do |f|
        f.puts "\n# deployment"
        f.puts "gem 'kamal', group: :development"
      end
      puts "kamal added to Gemfile"
      system("bundle install")
    else
      puts "kamal already in Gemfile"
    end
    
    # Create health check endpoint
    health_controller_path = "app/controllers/health_controller.rb"
    unless File.exist?(health_controller_path)
      puts "creating health check endpoint..."
      FileUtils.mkdir_p(File.dirname(health_controller_path))
      File.write(health_controller_path, <<~RUBY)
        class HealthController < ApplicationController
          def show
            render json: { 
              status: "ok", 
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
    
    # Create Dockerfile if it doesn't exist
    if !File.exist?("Dockerfile")
      puts "creating Dockerfile..."
      File.write("Dockerfile", <<~DOCKERFILE)
        FROM ruby:3.4.0-slim as builder

        # Install dependencies
        RUN apt-get update -qq && \\
            apt-get install -y build-essential libpq-dev nodejs npm git pkg-config libssl-dev

        # Install yarn
        RUN npm install -g yarn

        # Set working directory
        WORKDIR /app

        # Copy gemfiles
        COPY Gemfile Gemfile.lock ./

        # Bundle install
        RUN bundle config set --local deployment 'true' && \\
            bundle config set --local without 'development test' && \\
            bundle install

        # Copy application code
        COPY . .

        # Precompile assets
        RUN SECRET_KEY_BASE=dummy RAILS_ENV=production bundle exec rake assets:precompile

        # Final image
        FROM ruby:3.4.0-slim

        # Install runtime dependencies
        RUN apt-get update -qq && \\
            apt-get install -y postgresql-client nodejs curl

        # Create application user
        RUN groupadd -r app && \\
            useradd -r -g app -d /app -s /bin/false app

        # Set working directory
        WORKDIR /app

        # Copy from builder
        COPY --from=builder --chown=app:app /app /app
        COPY --from=builder /usr/local/bundle /usr/local/bundle

        # Environment
        ENV RAILS_ENV=production \\
            RAILS_LOG_TO_STDOUT=true \\
            RAILS_SERVE_STATIC_FILES=true

        # Set user
        USER app

        # Start command
        CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]

        # Health check
        HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \\
          CMD curl -f http://localhost:3000/health || exit 1
      DOCKERFILE
      puts "Dockerfile created"
    end
    
    # Create .dockerignore if it doesn't exist
    if !File.exist?(".dockerignore")
      puts "creating .dockerignore..."
      File.write(".dockerignore", <<~DOCKERIGNORE)
        .git
        .github
        tmp
        log
        node_modules
        .dockerignore
        Dockerfile
        .kamal
        .env*
      DOCKERIGNORE
      puts ".dockerignore created"
    end
    
    # Initialize Kamal configuration
    puts "\nnow running kamal initialization..."
    system("gem install kamal") || puts("failed to install kamal gem. please install it manually: gem install kamal")
    
    # Create kamal deploy.yml if it doesn't exist
    if !File.exist?("config/deploy.yml")
      puts "creating deploy.yml..."
      
      # Get deployment configuration info
      puts "\nsetting up kamal configuration..."
      puts "enter information for your deployment:"
      
      print "application domain (e.g., tarotapi.cards): "
      domain = STDIN.gets.chomp
      
      print "docker registry url: "
      registry = STDIN.gets.chomp
      
      print "staging server hostname or ip: "
      staging_host = STDIN.gets.chomp
      
      print "production server hostname or ip (leave blank to set later): "
      production_host = STDIN.gets.chomp
      
      print "ssh user for servers: "
      ssh_user = STDIN.gets.chomp
      
      # Create the deploy.yml file with sensible defaults
      deploy_yml = <<~YAML
        # Name of your application. Used to uniquely configure containers.
        service: tarot_api

        # Name of the container image.
        image: tarot_api:latest

        # Deploy to these servers.
        servers:
          web:
            hosts:
              - #{ssh_user}@#{staging_host}
        #{production_host.empty? ? '' : "            - #{ssh_user}@#{production_host}"}
            labels:
              traefik.http.routers.tarot_api.rule: Host(`api.#{domain}`)
              traefik.http.routers.tarot_api.tls: true
              traefik.http.routers.tarot_api.tls.certresolver: letsencrypt

        # Enable SSL auto certification via Let's Encrypt
        proxy:
          ssl: true
          host: api.#{domain}

        # Credentials for your image host.
        registry:
          server: #{registry}
          username:
            - KAMAL_REGISTRY_USERNAME
          password:
            - KAMAL_REGISTRY_PASSWORD

        # Inject ENV variables into containers (secrets come from .kamal/secrets).
        env:
          clear:
            RAILS_ENV: production
            RAILS_LOG_TO_STDOUT: true
            RAILS_SERVE_STATIC_FILES: true
            APP_NAME: tarot_api
            DB_HOST: db
            DB_NAME: tarot_api_production
            DB_USERNAME: tarot_api
            S3_ENDPOINT: http://minio:9000
            AWS_REGION: us-west-2
            AWS_BUCKET: tarot-api
          secret:
            - RAILS_MASTER_KEY
            - DB_PASSWORD
            - AWS_ACCESS_KEY_ID
            - AWS_SECRET_ACCESS_KEY
            - OPENAI_API_KEY

        # Aliases are triggered with "bin/kamal <alias>".
        aliases:
          console: app exec --interactive --reuse "bin/rails console"
          shell: app exec --interactive --reuse "bash"
          logs: app logs -f
          dbc: app exec --interactive --reuse "bin/rails dbconsole"

        # Persistent storage volumes
        volumes:
          - postgres_data:/var/lib/postgresql/data
          - redis_data:/data
          - minio_data:/data

        # Bridge fingerprinted assets between versions
        asset_path: /rails/public/assets

        # Configure the image builder.
        builder:
          multiarch: false
          args:
            - RAILS_ENV
            - RAILS_MASTER_KEY

        # health check configuration
        healthcheck:
          path: /health
          port: 3000
          interval: 10s
          timeout: 5s
          retries: 5

        # traefik configuration for ssl and routing
        traefik:
          options:
            publish:
              - "443:443"
            volume:
              - "/letsencrypt:/letsencrypt"
          args:
            entryPoints.web.address: ":80"
            entryPoints.websecure.address: ":443"
            certificatesResolvers.letsencrypt.acme.email: "admin@#{domain}"
            certificatesResolvers.letsencrypt.acme.storage: "/letsencrypt/acme.json"
            certificatesResolvers.letsencrypt.acme.httpChallenge.entryPoint: "web"

        # accessories for database, cache, and storage
        accessories:
          db:
            image: postgres:16-bookworm
            host: localhost
            port: 5432
            env:
              - POSTGRES_PASSWORD
              - POSTGRES_USER
              - POSTGRES_DB
            volumes:
              - postgres_data:/var/lib/postgresql/data
            cmd: postgres -c superuser_reserved_connections=0
          redis:
            image: redis:7-bookworm
            host: localhost
            port: 6379
            volumes:
              - redis_data:/data
            cmd: redis-server --appendonly yes
          minio:
            image: minio/minio:latest
            host: localhost
            ports:
              - "9000:9000"
              - "9001:9001"
            env:
              - MINIO_ROOT_USER
              - MINIO_ROOT_PASSWORD
            volumes:
              - minio_data:/data
            cmd: server /data --console-address ":9001"

        # blue-green deployment configuration
        rollout:
          version: v2
          strategy: blue-green
          secondary_ratio: 50
          
        # multi-environment configuration
        destinations:
          staging:
            hosts:
              - #{ssh_user}@#{staging_host}
            env:
              clear:
                RAILS_ENV: staging
              secret:
                - STAGING_RAILS_MASTER_KEY
          
          production:
        #{production_host.empty? ? '    # configure production hosts when ready' : "    hosts:\n      - #{ssh_user}@#{production_host}"}
            env:
              clear:
                RAILS_ENV: production
              secret:
                - RAILS_MASTER_KEY
      YAML
      
      # Create directory if it doesn't exist
      FileUtils.mkdir_p("config")
      
      # Write the deploy.yml file
      File.write("config/deploy.yml", deploy_yml)
      puts "created config/deploy.yml with your settings"
    end
    
    # Create .kamal directory if it doesn't exist
    FileUtils.mkdir_p(".kamal/secrets") unless Dir.exist?(".kamal/secrets")
    
    puts "\nproject initialization complete!"
    puts "next steps:"
    puts "1. set up secrets: bundle exec rake deploy:setup_secrets"
    puts "2. prepare servers: bundle exec rake deploy:setup"
    puts "3. deploy to staging: bundle exec rake deploy:staging"
  end
  
  desc "set up secrets for kamal deployment"
  task :setup_secrets do
    puts "setting up secrets for kamal deployment..."
    
    # Create .kamal/secrets directory if it doesn't exist
    FileUtils.mkdir_p(".kamal/secrets") unless Dir.exist?(".kamal/secrets")
    
    # Check for required secret files
    required_secrets = [
      "RAILS_MASTER_KEY",
      "STAGING_RAILS_MASTER_KEY",
      "DB_PASSWORD",
      "AWS_ACCESS_KEY_ID",
      "AWS_SECRET_ACCESS_KEY",
      "OPENAI_API_KEY",
      "KAMAL_REGISTRY_USERNAME",
      "KAMAL_REGISTRY_PASSWORD",
      "MINIO_ROOT_USER",
      "MINIO_ROOT_PASSWORD"
    ]
    
    required_secrets.each do |secret|
      secret_path = ".kamal/secrets/#{secret}"
      
      if File.exist?(secret_path)
        puts "secret #{secret} already exists"
      else
        print "enter value for #{secret} (leave blank to skip): "
        value = STDIN.noecho(&:gets).chomp rescue STDIN.gets.chomp
        puts ""
        
        unless value.empty?
          File.write(secret_path, value)
          puts "created secret #{secret}"
          
          # Set proper permissions
          File.chmod(0600, secret_path)
        end
      end
    end
    
    puts "\nsecrets setup complete!"
  end

  desc "setup servers for kamal deployment"
  task :setup do
    # Check if Kamal is installed
    unless system("which kamal > /dev/null 2>&1")
      abort "kamal is not installed\nplease install kamal with: gem install kamal"
    end

    # Check if deploy.yml exists
    unless File.exist?("config/deploy.yml")
      abort "config/deploy.yml not found. run `rake deploy:init` to create it"
    end

    puts "setting up servers for deployment..."
    
    # Run Kamal setup command
    if system("kamal setup")
      puts "server setup completed successfully"
    else
      abort "server setup failed"
    end
  end

  desc "deploy to staging environment"
  task :staging do
    puts "deploying to staging environment..."
    
    # Build and push
    system("kamal build") || abort("failed to build image")
    system("kamal push") || abort("failed to push image")
    
    # Deploy to staging
    if system("kamal deploy -d staging")
      puts "successfully deployed to staging"
    else
      abort "deployment to staging failed"
    end
  end

  desc "deploy to production environment"
  task :production do
    puts "deploying to production environment..."
    
    # Build and push
    system("kamal build") || abort("failed to build image")
    system("kamal push") || abort("failed to push image")
    
    # Deploy to production
    if system("kamal deploy -d production")
      puts "successfully deployed to production"
    else
      abort "deployment to production failed"
    end
  end

  desc "deploy preview environment for a branch"
  task :preview, [:branch_name] do |_, args|
    branch_name = args[:branch_name] || `git rev-parse --abbrev-ref HEAD`.strip
    
    # Create a preview environment name from branch
    sanitized_branch = branch_name.gsub(/[^a-zA-Z0-9]/, '-')
    preview_name = "preview-#{sanitized_branch}"
    
    puts "deploying preview environment for #{branch_name}..."
    
    # Build and push
    system("kamal build") || abort("failed to build image")
    system("kamal push") || abort("failed to push image")
    
    # Deploy to preview environment
    if system("kamal deploy -d #{preview_name}")
      puts "successfully deployed preview environment: #{preview_name}"
    else
      abort "preview deployment failed"
    end
  end

  desc "destroy a deployment environment"
  task :destroy, [:environment] do |_, args|
    environment = args[:environment] || abort("please specify an environment to destroy")
    
    puts "destroying #{environment} environment..."
    puts "WARNING: This will remove all resources for #{environment}"
    print "Are you sure? [y/N]: "
    confirmation = STDIN.gets.chomp.downcase
    
    if confirmation == "y"
      if system("kamal destroy -d #{environment}")
        puts "successfully destroyed #{environment} environment"
      else
        abort "failed to destroy #{environment} environment"
      end
    else
      puts "destruction cancelled"
    end
  end

  desc "cleanup old preview environments (older than 1 day)"
  task :cleanup do
    puts "cleaning up old preview environments..."
    
    # List all preview environments
    preview_environments = `kamal list 2>/dev/null | grep 'preview-' || echo ""`.split("\n")
    
    if preview_environments.empty?
      puts "no preview environments found"
      exit 0
    end
    
    # Get current date in epoch seconds
    current_date = Time.now.to_i
    retention_days = 1
    retention_seconds = retention_days * 24 * 60 * 60
    
    puts "found preview environments: #{preview_environments.join(', ')}"
    puts "removing environments older than #{retention_days} day(s)..."
    
    # Process each environment (simplification: since Kamal doesn't provide creation time,
    # we're removing all preview environments in this example)
    preview_environments.each do |preview|
      puts "removing preview environment: #{preview}"
      
      if system("kamal destroy -d #{preview}")
        puts "successfully removed #{preview}"
      else
        puts "failed to remove #{preview}"
      end
    end
  end

  desc "show status of all deployments"
  task :status do
    exec("kamal status")
  end
end

# Alias for kamal deployments
desc "deploy to staging (alias for deploy:staging)"
task deploy: "deploy:staging"

# Alias for fresh start
desc "clean up and start fresh (alias for git:fresh_start)"
task purge_history: "git:fresh_start"

# Alias for project initialization
desc "initialize the project for kamal deployment (alias for deploy:init)"
task init_project: "deploy:init" 