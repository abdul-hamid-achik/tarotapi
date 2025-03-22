namespace :env do
  desc "load environment variables from .env file"
  task :load_dotenv do
    # Only load from .env file
    env_file = ".env"
    if File.exist?(env_file)
      File.foreach(env_file) do |line|
        next if line.strip.empty? || line.strip.start_with?("#")
        key, value = line.strip.split("=", 2)
        ENV[key] = value if value && !key.strip.empty?
      end
    end

    # Docker will use .env.local through docker-compose, but .env should take precedence
    # when both exist (for consistency across environments)
  end

  desc "verify required environment variables"
  task verify: :load_dotenv do
    # List of required environment variables grouped by purpose
    required_envs = {
      "database" => %w[
        DATABASE_HOST
        DATABASE_PORT
        DATABASE_USERNAME
        DATABASE_PASSWORD
      ],
      "application" => %w[
        RAILS_MASTER_KEY
        RAILS_ENV
      ],
      "redis" => %w[
        REDIS_URL
      ],
      "aws" => %w[
        AWS_ACCESS_KEY_ID
        AWS_SECRET_ACCESS_KEY
        AWS_DEFAULT_REGION
        AWS_S3_BUCKET
      ],
      "stripe" => %w[
        STRIPE_SECRET_KEY
        STRIPE_PUBLISHABLE_KEY
      ]
    }

    # Collect missing environment variables
    missing = {}
    required_envs.each do |group, vars|
      missing_vars = vars.select { |var| ENV[var].to_s.empty? }
      missing[group] = missing_vars if missing_vars.any?
    end

    # Report missing environment variables
    if missing.any?
      puts "missing required environment variables:"
      missing.each do |group, vars|
        puts "  #{group}:"
        vars.each { |var| puts "    - #{var}" }
      end
    else
      puts "all required environment variables are set"
    end
  end

  desc "list all environment variables"
  task list: :load_dotenv do
    # Group environment variables by prefix
    env_groups = {}

    ENV.sort.each do |key, value|
      # Skip custom ruby env variables
      next if key.start_with?("_")

      group = key.split("_").first.downcase
      env_groups[group] ||= []
      # Mask sensitive values
      masked_value = sensitive_env?(key) ? "[MASKED]" : value
      env_groups[group] << [ key, masked_value ]
    end

    # Print environment variables grouped by prefix
    env_groups.sort.each do |group, envs|
      puts "#{group.upcase}:"
      envs.each { |key, value| puts "  #{key}=#{value}" }
      puts ""
    end
  end

  desc "generate a sample .env file"
  task :generate_sample do
    sample_file = ".env.example"

    # Read existing sample file if it exists
    existing_content = File.exist?(sample_file) ? File.read(sample_file) : ""

    # Template for sample env file
    sample_content = <<~ENV
      # Database Configuration
      DATABASE_HOST=localhost
      DATABASE_PORT=5432
      DATABASE_USERNAME=postgres
      DATABASE_PASSWORD=password

      # Application Settings
      RAILS_ENV=development
      RAILS_MASTER_KEY=your_master_key_here

      # Redis Configuration
      REDIS_URL=redis://localhost:6379/0

      # AWS Configuration
      AWS_ACCESS_KEY_ID=your_access_key
      AWS_SECRET_ACCESS_KEY=your_secret_key
      AWS_DEFAULT_REGION=mx-central-1
      AWS_S3_BUCKET=tarot-api-storage

      # Stripe Configuration
      STRIPE_SECRET_KEY=your_stripe_secret_key
      STRIPE_PUBLISHABLE_KEY=your_stripe_publishable_key

      # Docker Configuration
      DOCKER_RUNNING=false

      # Kamal Configuration
      KAMAL_REGISTRY_USERNAME=your_registry_username
      KAMAL_REGISTRY_PASSWORD=your_registry_password
    ENV

    # Only write if file doesn't exist or content is different
    if !File.exist?(sample_file) || existing_content != sample_content
      File.write(sample_file, sample_content)
      puts "generated sample environment file: #{sample_file}"
    else
      puts "sample environment file already exists and is up to date"
    end
  end

  private

  def enforce_env_priority
    # This is no longer needed as Docker Compose handles env loading
    # and .env is loaded directly through the rake task
  end

  def sensitive_env?(key)
    sensitive_patterns = %w[
      KEY PASSWORD SECRET TOKEN MASTER CREDENTIAL AUTH
    ]

    sensitive_patterns.any? { |pattern| key.upcase.include?(pattern) }
  end
end
