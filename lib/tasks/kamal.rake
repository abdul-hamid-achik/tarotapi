namespace :kamal do
  desc "initialize kamal with proper configuration setup"
  task :init do
    puts "initializing kamal configuration..."
    
    # Check if Kamal is installed
    unless system("which kamal > /dev/null 2>&1")
      puts "kamal not found, installing..."
      system("gem install kamal") || abort("failed to install kamal")
    end
    
    # Create deploy.yml if it doesn't exist
    if File.exist?("config/deploy.yml")
      print "config/deploy.yml already exists. overwrite? [y/N]: "
      overwrite = STDIN.gets.chomp.downcase
      if overwrite != "y"
        puts "keeping existing deploy.yml"
        return
      end
    end
    
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
    
    # Write the deploy.yml file
    File.write("config/deploy.yml", deploy_yml)
    puts "created config/deploy.yml with your settings"
    
    # Create .kamal directory if it doesn't exist
    Dir.mkdir(".kamal") unless Dir.exist?(".kamal")
    Dir.mkdir(".kamal/secrets") unless Dir.exist?(".kamal/secrets")
    
    puts "\nkamal initialization complete!"
    puts "next steps:"
    puts "1. review and edit config/deploy.yml as needed"
    puts "2. set up secrets in .kamal/secrets directory"
    puts "3. run 'bundle exec rake kamal:setup' to prepare servers"
    puts "4. run 'bundle exec rake kamal:deploy:staging' to deploy"
  end
  
  desc "set up secrets for kamal deployment"
  task :secrets do
    puts "setting up secrets for kamal deployment..."
    
    # Create .kamal/secrets directory if it doesn't exist
    Dir.mkdir(".kamal") unless Dir.exist?(".kamal")
    Dir.mkdir(".kamal/secrets") unless Dir.exist?(".kamal/secrets")
    
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
        value = STDIN.noecho(&:gets).chomp
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
  
  desc "prepare servers for kamal deployment"
  task :setup do
    # Check if deploy.yml exists
    unless File.exist?("config/deploy.yml")
      abort "config/deploy.yml not found. run 'bundle exec rake kamal:init' first"
    end
    
    puts "preparing servers for kamal deployment..."
    
    # Ask for environment
    print "which environment to prepare? [staging/production/all]: "
    env = STDIN.gets.chomp.downcase
    
    command = case env
              when "staging"
                "kamal setup -d staging"
              when "production"
                "kamal setup -d production"
              when "all"
                "kamal setup"
              else
                abort "invalid environment: #{env}"
              end
    
    # Run the setup command
    if system(command)
      puts "server preparation completed successfully"
    else
      abort "server preparation failed"
    end
    
    puts "\nsetup complete!"
    puts "your servers are now ready for deployment"
  end
  
  desc "check health and status of deployments"
  task :status do
    puts "checking deployment status..."
    
    # List all environments
    environments = `kamal list 2>/dev/null`.split("\n")
    
    if environments.empty?
      puts "no environments found. have you deployed yet?"
      exit 0
    end
    
    # Ask which environment to check if multiple
    env = if environments.size > 1
            print "which environment to check? [#{environments.join('/')}]: "
            input = STDIN.gets.chomp
            environments.include?(input) ? input : environments.first
          else
            environments.first
          end
    
    # Run the status command
    exec("kamal status -d #{env}")
  end
  
  desc "check logs from deployments"
  task :logs do
    puts "retrieving deployment logs..."
    
    # List all environments
    environments = `kamal list 2>/dev/null`.split("\n")
    
    if environments.empty?
      puts "no environments found. have you deployed yet?"
      exit 0
    end
    
    # Ask which environment to check if multiple
    env = if environments.size > 1
            print "which environment to check? [#{environments.join('/')}]: "
            input = STDIN.gets.chomp
            environments.include?(input) ? input : environments.first
          else
            environments.first
          end
    
    # Run the logs command
    exec("kamal logs -d #{env}")
  end
  
  namespace :deploy do
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
    
    desc "deploy to production environment (with confirmation)"
    task :production do
      puts "preparing to deploy to production environment..."
      puts "WARNING: this will deploy to production servers!"
      print "are you sure you want to proceed? [y/N]: "
      confirmation = STDIN.gets.chomp.downcase
      
      if confirmation == "y"
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
      else
        puts "production deployment cancelled"
      end
    end
    
    desc "deploy preview environment for a branch"
    task :preview, [:branch_name] do |_, args|
      branch_name = args[:branch_name] || `git rev-parse --abbrev-ref HEAD`.strip
      
      # Create a preview environment name from branch
      sanitized_branch = branch_name.gsub(/[^a-zA-Z0-9]/, '-')
      preview_name = "preview-#{sanitized_branch}"
      
      puts "deploying preview environment for #{branch_name}..."
      
      # Check if preview servers are configured
      unless system("kamal list 2>/dev/null | grep -q 'preview'")
        puts "preview servers not configured. configuring now..."
        
        # Get preview server details
        print "enter preview server hostname or ip: "
        preview_host = STDIN.gets.chomp
        
        print "enter ssh user for preview server: "
        preview_user = STDIN.gets.chomp
        
        # Update deploy.yml with preview configuration
        system(%{sed -i '' -e '/destinations:/a\\
  preview:\\
    hosts:\\
      - #{preview_user}@#{preview_host}\\
    env:\\
      clear:\\
        RAILS_ENV: preview\\
      secret:\\
        - STAGING_RAILS_MASTER_KEY
' config/deploy.yml}) || abort("failed to update deploy.yml with preview configuration")
      end
      
      # Build and push
      system("kamal build") || abort("failed to build image")
      system("kamal push") || abort("failed to push image")
      
      # Deploy to preview environment
      if system("kamal deploy -d preview --host #{preview_name}")
        puts "successfully deployed preview environment: #{preview_name}"
        # Output preview URL
        deploy_yml = YAML.load_file("config/deploy.yml")
        domain = deploy_yml.dig("proxy", "host") || "example.com"
        preview_url = "https://#{preview_name}.#{domain}"
        puts "preview available at: #{preview_url}"
      else
        abort "preview deployment failed"
      end
    end
  end
  
  desc "perform a rollback to previous version"
  task :rollback do
    puts "preparing to rollback deployment..."
    
    # List all environments
    environments = `kamal list 2>/dev/null`.split("\n")
    
    if environments.empty?
      puts "no environments found. have you deployed yet?"
      exit 0
    end
    
    # Ask which environment to rollback
    env = if environments.size > 1
            print "which environment to rollback? [#{environments.join('/')}]: "
            input = STDIN.gets.chomp
            environments.include?(input) ? input : environments.first
          else
            environments.first
          end
    
    puts "WARNING: this will rollback the #{env} environment to the previous version!"
    print "are you sure you want to proceed? [y/N]: "
    confirmation = STDIN.gets.chomp.downcase
    
    if confirmation == "y"
      # Run the rollback command
      if system("kamal rollback -d #{env}")
        puts "successfully rolled back #{env} environment"
      else
        abort "rollback failed"
      end
    else
      puts "rollback cancelled"
    end
  end
  
  desc "monitoring dashboard"
  task :monitor do
    puts "launching monitoring dashboard..."
    exec("kamal traefik -d staging")
  end
  
  desc "help information for kamal commands"
  task :help do
    puts <<~HELP
      kamal deployment commands:
      
      setup tasks:
        bundle exec rake kamal:init          # initialize kamal configuration
        bundle exec rake kamal:secrets       # set up secrets for deployment
        bundle exec rake kamal:setup         # prepare servers for deployment
      
      deployment tasks:
        bundle exec rake kamal:deploy:staging     # deploy to staging
        bundle exec rake kamal:deploy:production  # deploy to production
        bundle exec rake kamal:deploy:preview     # deploy preview environment
      
      management tasks:
        bundle exec rake kamal:status        # check deployment status
        bundle exec rake kamal:logs          # view deployment logs
        bundle exec rake kamal:rollback      # rollback to previous version
        bundle exec rake kamal:monitor       # launch monitoring dashboard
      
      data management:
        bundle exec rake data:backup         # backup database
        bundle exec rake data:restore        # restore database
    HELP
  end
end

# alias for convenience
desc "deploy to staging (alias for kamal:deploy:staging)"
task deploy: "kamal:deploy:staging" 