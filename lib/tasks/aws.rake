namespace :aws do
  desc "setup aws credentials"
  task :setup_credentials do
    # Check if credentials are already set in environment
    if ENV["AWS_ACCESS_KEY_ID"] && ENV["AWS_SECRET_ACCESS_KEY"]
      puts "using aws credentials from environment variables"

      # Create AWS credentials file to ensure aws-cli has access
      aws_dir = File.expand_path("~/.aws")
      Dir.mkdir(aws_dir) unless File.directory?(aws_dir)

      region = ENV["AWS_DEFAULT_REGION"] || "mx-central-1" # Default to Mexico region

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

      puts "aws credentials file created using #{region} region"
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
      
      # Get current region
      region = `aws configure get region`.strip
      puts "using aws region: #{region}"
      
      # Check if the region is available
      if region == "mx-central-1"
        region_check = system("aws ec2 describe-regions --region-names mx-central-1 > /dev/null 2>&1")
        unless region_check
          puts "warning: mx-central-1 region might not be available for your account"
          puts "consider using a different region by setting AWS_DEFAULT_REGION"
        end
      end
    else
      abort "aws credentials are invalid"
    end
  end

  desc "check region capabilities"
  task check_region: :verify_credentials do
    region = `aws configure get region`.strip
    puts "checking aws region #{region} capabilities..."
    
    # Check service availability
    services = {
      "ec2" => "describe-instances",
      "rds" => "describe-db-instances",
      "s3" => "list-buckets",
      "elasticache" => "describe-cache-clusters",
      "cloudwatch" => "list-metrics",
      "sns" => "list-topics",
      "budgets" => "describe-budgets",
      "lambda" => "list-functions"
    }
    
    puts "\nservice availability in #{region}:"
    
    services.each do |service, command|
      available = system("aws #{service} #{command} > /dev/null 2>&1")
      status = available ? "✅" : "❌"
      puts "#{status} #{service}"
    end
    
    # If using Mexico region, check additional details
    if region == "mx-central-1"
      puts "\n#{region} region details:"
      puts "- availability zones: 3 (mx-central-1a, mx-central-1b, mx-central-1c)"
      puts "- data residency: supports data sovereignty requirements in Mexico"
      puts "- latency: improved performance for users in Mexico and Latin America"
      
      # Check availability zones
      puts "\navailability zones:"
      system("aws ec2 describe-availability-zones --region #{region} | grep ZoneName")
    end
    
    puts "\nregion capability check complete"
  end

  desc "setup aws s3 buckets"
  task setup_s3: :verify_credentials do
    region = `aws configure get region`.strip
    bucket_name = ENV["AWS_S3_BUCKET"] || "tarot-api-#{region}-#{SecureRandom.hex(4)}"

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

  desc "setup infrastructure using kamal"
  task setup_infra: :verify_credentials do
    # Check if kamal is installed
    unless system("which kamal > /dev/null 2>&1")
      abort "kamal is not installed\nplease install kamal with: gem install kamal"
    end

    # Check if required environment variables are set
    required_envs = {
      "rails_master_key" => "RAILS_MASTER_KEY"
    }

    missing_envs = required_envs.select { |_, env_var| ENV[env_var].to_s.empty? }

    unless missing_envs.empty?
      puts "missing required environment variables:"
      missing_envs.each { |name, env_var| puts "  - #{env_var} (#{name})" }
      abort "please set the required environment variables and try again"
    end

    # Determine environment
    deploy_env = ENV["DEPLOY_ENV"] || "staging"
    app_name = ENV["APP_NAME"] || "tarotapi"
    
    puts "setting up infrastructure for #{app_name} in #{deploy_env} environment..."
    
    # Build and push Docker image
    puts "building and pushing docker image..."
    unless system("kamal build")
      abort "failed to build docker image"
    end
    
    unless system("kamal push")
      abort "failed to push docker image"
    end
    
    # Deploy the application with blue-green strategy
    puts "deploying application with blue-green deployment strategy..."
    
    deploy_cmd = "kamal deploy"
    deploy_cmd += " -d #{deploy_env}" if deploy_env
    
    unless system(deploy_cmd)
      abort "deployment failed"
    end
    
    puts "deployed #{app_name} to #{deploy_env} successfully"
    
    # Show deployment status
    system("kamal status -d #{deploy_env}")
  end

  desc "provision servers for kamal deployment"
  task provision_servers: :verify_credentials do
    # Check if required environment variables are set
    required_envs = {
      "ssh_key_path" => "SSH_KEY_PATH"
    }

    missing_envs = required_envs.select { |_, env_var| ENV[env_var].to_s.empty? }

    unless missing_envs.empty?
      puts "missing required environment variables:"
      missing_envs.each { |name, env_var| puts "  - #{env_var} (#{name})" }
      abort "please set the required environment variables and try again"
    end

    # Determine environment
    deploy_env = ENV["DEPLOY_ENV"] || "staging"
    
    puts "provisioning servers for #{deploy_env} environment..."
    
    # Run Kamal setup to prepare servers
    setup_cmd = "kamal setup"
    setup_cmd += " -d #{deploy_env}" if deploy_env
    
    unless system(setup_cmd)
      abort "server setup failed"
    end
    
    puts "servers provisioned successfully for #{deploy_env} environment"
  end

  desc "create preview environment"
  task create_preview: :verify_credentials do
    # Check if required environment variables are set
    required_envs = {
      "rails_master_key" => "RAILS_MASTER_KEY",
      "branch_or_preview_name" => "BRANCH_NAME"
    }

    missing_envs = required_envs.select { |_, env_var| ENV[env_var].to_s.empty? }

    unless missing_envs.empty?
      puts "missing required environment variables:"
      missing_envs.each { |name, env_var| puts "  - #{env_var} (#{name})" }
      abort "please set the required environment variables and try again"
    end

    branch_name = ENV["BRANCH_NAME"]
    sanitized_branch = branch_name.gsub(/[^a-zA-Z0-9]/, '-')
    preview_name = "preview-#{sanitized_branch}"
    
    puts "creating preview environment for branch: #{branch_name}"
    puts "preview name: #{preview_name}"
    
    # Build and push Docker image
    puts "building and pushing docker image..."
    unless system("kamal build")
      abort "failed to build docker image"
    end
    
    unless system("kamal push")
      abort "failed to push docker image"
    end
    
    # Deploy with preview destination
    deploy_cmd = "kamal deploy -d #{preview_name}"
    
    unless system(deploy_cmd)
      abort "preview deployment failed"
    end
    
    puts "preview environment deployed successfully: #{preview_name}"
    system("kamal status -d #{preview_name}")
  end

  desc "clean up preview environment"
  task cleanup_preview: :verify_credentials do
    preview_name = ENV["PREVIEW_NAME"]
    
    if preview_name.nil? || preview_name.empty?
      abort "PREVIEW_NAME environment variable must be set"
    end
    
    puts "cleaning up preview environment: #{preview_name}"
    
    # Destroy the preview environment
    unless system("kamal destroy -d #{preview_name}")
      abort "failed to destroy preview environment"
    end
    
    puts "preview environment cleaned up successfully: #{preview_name}"
  end
end
