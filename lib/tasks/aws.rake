namespace :aws do
  desc "setup aws credentials"
  task :setup_credentials do
    # Check if credentials are already set in environment
    if ENV["AWS_ACCESS_KEY_ID"] && ENV["AWS_SECRET_ACCESS_KEY"]
      puts "using aws credentials from environment variables"

      # Create AWS credentials file to ensure aws-cli has access
      aws_dir = File.expand_path("~/.aws")
      Dir.mkdir(aws_dir) unless File.directory?(aws_dir)

      region = ENV["AWS_DEFAULT_REGION"] || "us-west-2"

      # Create credentials file
      File.open(File.join(aws_dir, "credentials"), "w") do |f|
        f.puts "[default]"
        f.puts "aws_access_key_id = #{ENV["AWS_ACCESS_KEY_ID"]}"
        f.puts "aws_secret_access_key = #{ENV["AWS_SECRET_ACCESS_KEY"]}"
      end

      # Create config file
      File.open(File.join(aws_dir, "config"), "w") do |f|
        f.puts "[default]"
        f.puts "region = #{region}"
        f.puts "output = json"
      end

      puts "aws credentials file created"
    else
      abort "aws credentials not found in environment variables\nset AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, and optionally AWS_DEFAULT_REGION"
    end
  end

  desc "verify aws credentials"
  task verify_credentials: :setup_credentials do
    # Check if aws cli is installed
    unless system("which aws > /dev/null 2>&1")
      abort "aws cli is not installed\nplease install aws cli following the instructions at https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html"
    end

    # Verify credentials work
    if system("aws sts get-caller-identity > /dev/null 2>&1")
      puts "aws credentials verified successfully"
    else
      abort "aws credentials are invalid"
    end
  end

  desc "setup aws s3 buckets"
  task setup_s3: :verify_credentials do
    bucket_name = ENV["AWS_S3_BUCKET"] || "tarot-api-#{SecureRandom.hex(4)}"
    region = ENV["AWS_DEFAULT_REGION"] || "us-west-2"

    puts "setting up s3 bucket #{bucket_name} in region #{region}..."

    # Check if bucket exists
    if system("aws s3 ls s3://#{bucket_name} > /dev/null 2>&1")
      puts "bucket #{bucket_name} already exists"
    else
      # Create bucket
      if system("aws s3 mb s3://#{bucket_name} --region #{region}")
        puts "bucket #{bucket_name} created successfully"

        # Set bucket for public read access for tarot card images
        if system("aws s3api put-bucket-policy --bucket #{bucket_name} --policy '{\"Version\":\"2012-10-17\",\"Statement\":[{\"Sid\":\"PublicReadForGetBucketObjects\",\"Effect\":\"Allow\",\"Principal\":\"*\",\"Action\":\"s3:GetObject\",\"Resource\":\"arn:aws:s3:::#{bucket_name}/*\"}]}'")
          puts "bucket policy set for public read access"
        else
          puts "warning: failed to set bucket policy"
        end
      else
        abort "failed to create bucket #{bucket_name}"
      end
    end

    # Update .env file with bucket name if not already set
    if ENV["AWS_S3_BUCKET"].nil?
      env_file = ".env"
      env_content = File.exist?(env_file) ? File.read(env_file) : ""

      if env_content.include?("AWS_S3_BUCKET=")
        # Replace existing value
        new_content = env_content.gsub(/^AWS_S3_BUCKET=.*$/, "AWS_S3_BUCKET=#{bucket_name}")
      else
        # Add new value
        new_content = env_content + "\nAWS_S3_BUCKET=#{bucket_name}"
      end

      File.write(env_file, new_content)
      puts "updated #{env_file} with AWS_S3_BUCKET=#{bucket_name}"
    end
  end

  desc "setup aws infrastructure using pulumi"
  task setup_infra: :verify_credentials do
    # Check if pulumi is installed
    unless system("which pulumi > /dev/null 2>&1")
      abort "pulumi is not installed\nplease install pulumi following the instructions at https://www.pulumi.com/docs/install/"
    end

    # Check if required environment variables are set
    required_envs = {
      "rails_master_key" => "RAILS_MASTER_KEY",
      "pulumi_config_passphrase" => "PULUMI_CONFIG_PASSPHRASE"
    }

    missing_envs = required_envs.select { |_, env_var| ENV[env_var].to_s.empty? }

    unless missing_envs.empty?
      puts "missing required environment variables:"
      missing_envs.each { |name, env_var| puts "  - #{env_var} (#{name})" }
      abort "please set the required environment variables and try again"
    end

    # Setup Pulumi backend
    pulumi_bucket = ENV["PULUMI_STATE_BUCKET"]

    if pulumi_bucket && !pulumi_bucket.empty?
      # Use S3 for state storage
      puts "using s3 bucket for pulumi state: #{pulumi_bucket}"

      unless system("pulumi login s3://#{pulumi_bucket}")
        puts "failed to configure s3 backend, falling back to local storage"
        setup_local_backend
      end
    else
      # Setup local backend
      pulumi_dir = File.expand_path("../../infrastructure/.pulumi", __dir__)
      ENV["PULUMI_BACKEND_URL"] = "file://#{pulumi_dir}"
      puts "configured pulumi to use local file backend at: #{ENV['PULUMI_BACKEND_URL']}"
      puts "warning: local state storage is not recommended for production"

      # Ensure the directory exists
      FileUtils.mkdir_p(pulumi_dir)

      # Ensure .pulumi is in .gitignore
      gitignore_path = File.expand_path("../../.gitignore", __dir__)
      if File.exist?(gitignore_path)
        gitignore_content = File.read(gitignore_path)
        unless gitignore_content.include?("infrastructure/.pulumi")
          File.open(gitignore_path, "a") do |f|
            f.puts "\n# Local Pulumi state - contains sensitive data"
            f.puts "infrastructure/.pulumi/"
          end
          puts "added infrastructure/.pulumi to .gitignore for security"
        end
      end
    end

    # Navigate to infrastructure directory and run pulumi
    infra_dir = File.expand_path("../../infrastructure", __dir__)
    unless Dir.exist?(infra_dir)
      abort "infrastructure directory not found at #{infra_dir}"
    end

    Dir.chdir(infra_dir) do
      # Run pulumi commands
      system("pulumi stack select dev --create") || abort("failed to select pulumi stack")
      system("pulumi up") || abort("failed to update infrastructure")
    end

    puts "infrastructure setup complete"
  end

  def setup_local_backend
    pulumi_dir = File.expand_path("../../infrastructure/.pulumi", __dir__)
    ENV["PULUMI_BACKEND_URL"] = "file://#{pulumi_dir}"

    # Ensure the directory exists
    FileUtils.mkdir_p(pulumi_dir)
  end
end
