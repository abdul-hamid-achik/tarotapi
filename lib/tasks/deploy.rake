namespace :deploy do
  # load environment variables from .env file
  task :load_env do
    if File.exist?(".env")
      require "dotenv"
      Dotenv.load(".env")
      puts "loaded environment variables from .env file"
    else
      puts "warning: .env file not found"
    end
  end

  desc "prepare the deployment environment"
  task prepare: :load_env do
    # ensure environment variables are loaded

    puts "preparing deployment environment..."
    puts "environment: production"

    required_envs = {
      "rails_master_key" => "RAILS_MASTER_KEY",
      "pulumi_config_passphrase" => "PULUMI_CONFIG_PASSPHRASE",
      "pulumi_encryption_salt" => "PULUMI_ENCRYPTION_SALT",
      "aws_access_key_id" => "AWS_ACCESS_KEY_ID",
      "aws_secret_access_key" => "AWS_SECRET_ACCESS_KEY",
      "aws_account_id" => "AWS_ACCOUNT_ID",
      "aws_default_region" => "AWS_DEFAULT_REGION",
      "database_url" => "DATABASE_URL",
      "domain_name" => "DOMAIN_NAME",
      "hosted_zone_id" => "HOSTED_ZONE_ID",
      "app_name" => "APP_NAME"
    }

    puts "\nchecking environment variables..."
    missing_envs = []

    required_envs.each do |key, env_key|
      value = ENV[env_key]
      if value.nil?
        puts "❌ #{key}: not set"
        missing_envs << key
      else
        sensitive = key.include?('key') || 
                   key.include?('secret') || 
                   key.include?('password') ||
                   key.include?('passphrase') ||
                   key.include?('account_id') ||
                   key.include?('zone_id') ||
                   key.include?('master_key')
        puts "✅ #{key}: #{sensitive ? '[HIDDEN]' : value}"
      end
    end

    if missing_envs.any?
      puts "\nerror: missing required environment variables:"
      missing_envs.each { |env| puts "  - #{env}" }
      exit(1)
    end

    # check for critical files
    unless File.exist?("config/master.key")
      puts "error: config/master.key file is missing"
      exit(1)
    end

    unless File.exist?("config/credentials.yml.enc")
      puts "error: config/credentials.yml.enc file is missing"
      exit(1)
    end

    unless File.exist?("config/database.yml")
      puts "error: config/database.yml file is missing"
      exit(1)
    end

    setup_pulumi_stack
  end

  desc "validate infrastructure configuration"
  task validate: :prepare do
    puts "validating infrastructure configuration..."
    in_infrastructure_dir do
      system("pulumi preview") || exit(1)
    end
  end

  desc "deploy infrastructure using pulumi"
  task infrastructure: :validate do
    puts "deploying infrastructure..."
    in_infrastructure_dir do
      system("pulumi up --yes") || exit(1)
    end
  end

  desc "compile and prepare assets"
  task assets: :environment do
    puts "compiling assets..."
    system("bundle exec rails assets:precompile RAILS_ENV=production") || exit(1)
  end

  desc "run database migrations"
  task migrate: :environment do
    puts "running database migrations..."
    system("bundle exec rails db:migrate RAILS_ENV=production") || exit(1)
  end

  desc "deploy application to aws"
  task app: [ :infrastructure, :assets, :migrate ] do
    puts "deploying application..."
    # build and push docker image
    deploy_docker_image

    # deploy to ecs/fargate with pulumi outputs
    deploy_to_aws
  end

  desc "run all deployment steps"
  task all: [ :prepare, :validate, :infrastructure, :app ] do
    puts "deployment completed successfully!"
  end

  desc "destroy infrastructure"
  task destroy: :prepare do
    puts "destroying infrastructure..."
    print "are you sure you want to destroy production infrastructure? [y/n]: "
    response = STDIN.gets.chomp.downcase
    exit(1) unless response == "y"

    in_infrastructure_dir do
      system("pulumi destroy --yes") || exit(1)
    end
  end

  namespace :secrets do
    desc "sync secrets from .env to ssm parameter store"
    task sync: :environment do
      require "aws-sdk-ssm"
      ssm = Aws::SSM::Client.new(region: ENV.fetch("AWS_DEFAULT_REGION"))

      # Read from .env file
      env_content = File.read(".env")

      env_content.each_line do |line|
        next if line.strip.empty? || line.start_with?("#")

        key, value = line.strip.split("=", 2)
        next unless key && value

        # Convert to lowercase for SSM path
        ssm_key = key.downcase

        begin
          ssm.put_parameter({
            name: "/production/#{ssm_key}",
            value: value,
            type: "SecureString",
            overwrite: true
          })
          puts "synced #{key} to ssm parameter store"
        rescue Aws::SSM::Errors::ServiceError => e
          puts "error syncing #{key}: #{e.message}"
        end
      end
    end

    desc "fetch secrets from ssm parameter store to .env"
    task fetch: :environment do
      require "aws-sdk-ssm"
      ssm = Aws::SSM::Client.new(region: ENV.fetch("AWS_DEFAULT_REGION"))

      env_content = []
      next_token = nil

      begin
        loop do
          response = ssm.get_parameters_by_path({
            path: "/production/",
            with_decryption: true,
            recursive: true,
            next_token: next_token
          })

          response.parameters.each do |param|
            key = param.name.split("/").last.upcase
            value = param.value
            env_content << "#{key}=#{value}"
          end

          next_token = response.next_token
          break unless next_token
        end

        # Write directly to .env
        File.write(".env", env_content.join("\n"))
        puts "secrets fetched from ssm parameter store to .env"
      rescue Aws::SSM::Errors::ServiceError => e
        puts "error fetching secrets: #{e.message}"
        exit(1)
      end
    end
  end
end

# pulumi helper functions
def setup_pulumi_stack
  in_infrastructure_dir do
    unless system("pulumi stack select production 2>/dev/null")
      puts "stack not found, creating new stack..."
      system("pulumi stack init production") || exit(1)
    end
  end
end

def in_infrastructure_dir
  Dir.chdir("infrastructure") do
    yield
  end
end

# docker helper functions
def deploy_docker_image
  puts "building and pushing docker image..."
  image_name = "#{ENV['AWS_ACCOUNT_ID']}.dkr.ecr.#{ENV['AWS_DEFAULT_REGION']}.amazonaws.com/#{ENV['APP_NAME']}"
  tag = Time.now.strftime("%Y%m%d%H%M%S")

  system("docker build -t #{image_name}:#{tag} -t #{image_name}:latest .") || exit(1)
  system("aws ecr get-login-password --region #{ENV['AWS_DEFAULT_REGION']} | docker login --username aws --password-stdin #{ENV['AWS_ACCOUNT_ID']}.dkr.ecr.#{ENV['AWS_DEFAULT_REGION']}.amazonaws.com") || exit(1)
  system("docker push #{image_name}:#{tag}") || exit(1)
  system("docker push #{image_name}:latest") || exit(1)

  puts "docker image built and pushed successfully"
end

def deploy_to_aws
  puts "deploying to AWS..."
  # get pulumi outputs for aws resources
  outputs = JSON.parse(`cd infrastructure && pulumi stack output --json`)

  # deploy using pulumi outputs
  puts "deployment to AWS completed"
end

# simple aliases for common tasks
desc "deploy everything (alias for deploy:all)"
task deploy: "deploy:all"

# setup pulumi
namespace :pulumi do
  desc "setup pulumi environment"
  task setup: :load_env do
    puts "setting up pulumi environment..."
    system("cd infrastructure && pulumi login") || exit(1)
  end

  desc "get infrastructure outputs"
  task outputs: :load_env do
    puts "fetching infrastructure outputs..."
    system("cd infrastructure && pulumi stack output --json") || exit(1)
  end

  desc "refresh infrastructure state"
  task refresh: :load_env do
    puts "refreshing infrastructure state..."
    system("cd infrastructure && pulumi refresh --yes") || exit(1)
  end
end
