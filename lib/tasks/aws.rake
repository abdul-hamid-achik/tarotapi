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
        if !region_check
          puts "warning: region mx-central-1 might not be available yet"
          puts "if you encounter issues, switch to a different region like us-east-1"
        end
      end
    else
      abort "aws credentials verification failed\nplease check your credentials and try again"
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

  desc "create a cloudfront distribution for the s3 bucket"
  task :create_cdn, [ :bucket_name ] => :verify_credentials do |t, args|
    bucket_name = args[:bucket_name]
    abort "bucket name is required" unless bucket_name

    puts "creating cloudfront distribution for bucket: #{bucket_name}"

    # This should now use Pulumi instead
    puts "this task has been moved to Pulumi infrastructure code"
    puts "run 'bundle exec rake deploy:infra:staging' to provision infrastructure including CDN"
  end

  desc "cleanup orphaned aws resources"
  task cleanup: :verify_credentials do
    puts "cleaning up orphaned aws resources..."

    # This task is now better handled by Pulumi's state tracking
    puts "recommended: use pulumi to manage resources and avoid orphaned resources"
    puts "run 'bundle exec rake pulumi:deploy' with the appropriate environment to ensure resources are tracked"
  end

  desc "Ensure AWS region is set correctly across all configurations"
  task :set_region, [ :region ] => :environment do |t, args|
    region = args[:region] || "us-west-2"

    puts "Setting AWS region to #{region} across all configurations..."

    # Check if AWS CLI is installed
    unless system("which aws > /dev/null 2>&1")
      abort "Error: AWS CLI is not installed. Please install it first."
    end

    # 1. Set AWS CLI config
    puts "Setting AWS CLI default region..."
    system("aws configure set region #{region}")

    # 2. Update Pulumi configs
    puts "Updating Pulumi configuration files..."

    # Find all Pulumi.yaml files
    pulumi_files = Dir.glob(File.join(Rails.root, "infra", "pulumi", "**", "Pulumi.yaml"))
    pulumi_files.each do |file|
      content = File.read(file)
      if content.match?(/aws:region:/)
        updated_content = content.gsub(/aws:region:.*/, "aws:region: #{region}")
        File.write(file, updated_content)
        puts "  ✅ Updated #{file}"
      else
        puts "  ⚠️ No aws:region found in #{file}"
      end
    end

    # 3. Update config.yaml file
    config_file = File.join(Rails.root, "infra", "pulumi", "config.yaml")
    if File.exist?(config_file)
      content = File.read(config_file)
      if content.match?(/region:.*/)
        updated_content = content.gsub(/region:.*/, "region: #{region}  # AWS region")
        File.write(config_file, updated_content)
        puts "  ✅ Updated #{config_file}"
      else
        puts "  ⚠️ No region setting found in #{config_file}"
      end
    end

    # 4. Update GitHub workflow files
    puts "Updating GitHub workflow files..."

    workflow_files = Dir.glob(File.join(Rails.root, ".github", "workflows", "*.yml"))
    workflow_files.each do |file|
      content = File.read(file)

      # Update aws-region parameter
      if content.match?(/aws-region:/)
        updated_content = content.gsub(/aws-region:.*/, "aws-region: #{region}  # AWS region")
        File.write(file, updated_content)
        puts "  ✅ Updated aws-region in #{file}"
      end

      # Update environment variables
      if content.match?(/AWS_REGION=/)
        updated_content = content.gsub(/AWS_REGION=.*/, "AWS_REGION=#{region}")
        updated_content = updated_content.gsub(/AWS_DEFAULT_REGION=.*/, "AWS_DEFAULT_REGION=#{region}")
        File.write(file, updated_content)
        puts "  ✅ Updated AWS_REGION in #{file}"
      end
    end

    # 5. Set environment variables for the current process
    ENV["AWS_REGION"] = region
    ENV["AWS_DEFAULT_REGION"] = region

    puts "AWS region has been set to #{region} in all configurations."
    puts "To verify the changes, run: rake aws:check_region"
  end

  desc "Check current AWS region configuration"
  task check_region: :environment do
    puts "Checking AWS region configuration..."

    # Check if AWS CLI is installed
    unless system("which aws > /dev/null 2>&1")
      abort "Error: AWS CLI is not installed. Please install it first."
    end

    # 1. Check AWS CLI config
    region = `aws configure get region`.strip
    puts "AWS CLI default region: #{region.empty? ? 'not set' : region}"

    # 2. Check environment variables
    puts "AWS_REGION environment variable: #{ENV['AWS_REGION'] || 'not set'}"
    puts "AWS_DEFAULT_REGION environment variable: #{ENV['AWS_DEFAULT_REGION'] || 'not set'}"

    # 3. Check Pulumi configurations
    puts "\nPulumi configuration files:"
    pulumi_files = Dir.glob(File.join(Rails.root, "infra", "pulumi", "**", "Pulumi.yaml"))
    pulumi_files.each do |file|
      content = File.read(file)
      region_match = content.match(/aws:region: (.*)/)
      pulumi_region = region_match ? region_match[1].strip : "not found"
      puts "  #{File.basename(file)}: #{pulumi_region}"
    end

    # 4. Check GitHub workflow files
    puts "\nGitHub workflow files:"
    workflow_files = Dir.glob(File.join(Rails.root, ".github", "workflows", "*.yml"))
    workflow_files.each do |file|
      content = File.read(file)
      region_match = content.match(/aws-region: (.*)/)
      workflow_region = region_match ? region_match[1].strip : "not found"
      puts "  #{File.basename(file)}: #{workflow_region}"
    end

    # 5. Check AWS account access
    puts "\nVerifying AWS account access:"
    system("aws sts get-caller-identity")

    puts "\nTo set a consistent region across all configurations, run: rake aws:set_region[region_name]"
    puts "Example: rake aws:set_region[us-west-2]"
  end
end
