namespace :pulumi do
  require "fileutils"
  require "json"
  require "yaml"
  require "open3"

  # infrastructure directory
  PULUMI_DIR = File.join(Rails.root, "infra", "pulumi")
  ENVIRONMENTS = %w[production staging preview]

  desc "install pulumi cli if not present"
  task :ensure_installed do
    # check if pulumi is installed
    if system("which pulumi > /dev/null 2>&1")
      puts "pulumi is already installed"
    else
      puts "installing pulumi..."
      if system("brew install pulumi > /dev/null 2>&1")
        puts "pulumi installed via homebrew"
      else
        puts "installing pulumi via official installer..."
        # fallback to official installer
        system("curl -fsSL https://get.pulumi.com | sh")
        puts "pulumi installed"
      end
    end

    # check version
    pulumi_version = `pulumi version`.strip
    puts "using pulumi #{pulumi_version}"
  end

  desc "bootstrap s3 bucket for pulumi state"
  task bootstrap: :ensure_installed do
    # check if aws credentials are set
    unless ENV["AWS_ACCESS_KEY_ID"] && ENV["AWS_SECRET_ACCESS_KEY"]
      abort "error: aws credentials not set. please set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY"
    end

    # use the region from the aws config
    region = ENV["AWS_DEFAULT_REGION"] || ENV["AWS_REGION"] || "mx-central-1"

    # bucket name for state storage
    bucket_name = "tarotapi-pulumi-state"

    puts "bootstrapping s3 bucket for pulumi state..."

    # check if bucket exists
    stdout, stderr, status = Open3.capture3("aws s3api head-bucket --bucket #{bucket_name} 2>&1")

    if status.success?
      puts "bucket #{bucket_name} already exists"
    else
      if stderr.include?("Not Found") || stderr.include?("NoSuchBucket")
        puts "creating bucket #{bucket_name} in region #{region}..."

        # create bucket with appropriate region syntax
        if region == "us-east-1"
          # us-east-1 doesn't use LocationConstraint
          system("aws s3api create-bucket --bucket #{bucket_name} --region #{region}")
        else
          system("aws s3api create-bucket --bucket #{bucket_name} --region #{region} --create-bucket-configuration LocationConstraint=#{region}")
        end

        if $?.success?
          puts "bucket created successfully"

          # enable versioning for state safety
          puts "enabling versioning on bucket..."
          system("aws s3api put-bucket-versioning --bucket #{bucket_name} --versioning-configuration Status=Enabled")

          # enable encryption
          puts "enabling encryption on bucket..."
          system("aws s3api put-bucket-encryption --bucket #{bucket_name} --server-side-encryption-configuration '{\"Rules\": [{\"ApplyServerSideEncryptionByDefault\": {\"SSEAlgorithm\": \"AES256\"}}]}'")

          # add lifecycle rule to expire old versions after 30 days
          puts "adding lifecycle rules for old versions..."
          system("aws s3api put-bucket-lifecycle-configuration --bucket #{bucket_name} --lifecycle-configuration '{\"Rules\": [{\"Status\": \"Enabled\", \"Prefix\": \"\", \"NoncurrentVersionExpiration\": {\"NoncurrentDays\": 30}, \"ID\": \"Delete old versions\"}]}'")

          # block public access
          puts "blocking public access..."
          system("aws s3api put-public-access-block --bucket #{bucket_name} --public-access-block-configuration '{\"BlockPublicAcls\": true, \"IgnorePublicAcls\": true, \"BlockPublicPolicy\": true, \"RestrictPublicBuckets\": true}'")

          puts "s3 bucket #{bucket_name} configured for pulumi state"
        else
          abort "error: failed to create s3 bucket for pulumi state"
        end
      else
        abort "error checking s3 bucket: #{stderr}"
      end
    end

    # configure pulumi to use the s3 bucket
    puts "configuring pulumi to use s3 bucket for state storage..."
    if system("pulumi login s3://#{bucket_name}")
      puts "pulumi configured to use s3://#{bucket_name} for state storage"
    else
      puts "warning: failed to configure pulumi for s3 state storage"
      puts "using local state storage instead..."
      system("pulumi login --local")
    end
  end

  desc "initialize pulumi project"
  task init: :bootstrap do
    puts "initializing pulumi project..."

    # ensure directory exists
    FileUtils.mkdir_p(PULUMI_DIR)

    # check if project already initialized
    if File.exist?(File.join(PULUMI_DIR, "Pulumi.yaml"))
      puts "pulumi project already initialized at #{PULUMI_DIR}"
    else
      # initialize project from existing yaml file
      puts "initializing pulumi project from existing configuration..."
    end

    # create stacks for each environment if they don't exist
    ENVIRONMENTS.each do |env|
      stack_name = "tarot-api-#{env}"

      # check if stack exists
      stdout, stderr, status = Open3.capture3("cd #{PULUMI_DIR} && pulumi stack ls")

      unless stdout.include?(stack_name)
        puts "creating stack for #{env} environment..."
        system("cd #{PULUMI_DIR} && pulumi stack init #{stack_name}")

        # configure stack
        system("cd #{PULUMI_DIR} && pulumi config set environment #{env}")
        system("cd #{PULUMI_DIR} && pulumi config set aws:region mx-central-1")

        # cost saving for non-production environments
        if env != "production"
          system("cd #{PULUMI_DIR} && pulumi config set enable-cost-saving true")
        else
          system("cd #{PULUMI_DIR} && pulumi config set enable-cost-saving false")
        end

        # set domain
        system("cd #{PULUMI_DIR} && pulumi config set domain tarotapi.cards")

        puts "#{env} stack initialized"
      else
        puts "stack for #{env} environment already exists"
      end
    end

    puts "pulumi project initialization complete"
  end

  desc "set secret values for the project"
  task :set_secrets, [ :environment ] => :init do |t, args|
    env = args[:environment] || "staging"
    abort "invalid environment: #{env}" unless ENVIRONMENTS.include?(env)

    stack_name = "tarot-api-#{env}"
    puts "setting secrets for #{stack_name} stack..."

    # select stack
    system("cd #{PULUMI_DIR} && pulumi stack select #{stack_name}")

    # database password
    db_password = ENV["DB_PASSWORD"] || SecureRandom.hex(16)
    system("cd #{PULUMI_DIR} && pulumi config set --secret databasePassword #{db_password}")

    # rails master key
    if File.exist?(File.join(Rails.root, "config", "master.key"))
      rails_master_key = File.read(File.join(Rails.root, "config", "master.key")).strip
      system("cd #{PULUMI_DIR} && pulumi config set --secret railsMasterKey #{rails_master_key}")
    else
      puts "warning: config/master.key not found, skipping rails master key configuration"
    end

    # openai api key
    if ENV["OPENAI_API_KEY"]
      system("cd #{PULUMI_DIR} && pulumi config set --secret openaiApiKey #{ENV["OPENAI_API_KEY"]}")
    else
      puts "warning: OPENAI_API_KEY not set in environment, skipping"
    end

    puts "secrets set for #{stack_name} stack"
  end

  desc "deploy infrastructure for an environment"
  task :deploy, [ :environment ] => :init do |t, args|
    env = args[:environment] || "staging"
    abort "invalid environment: #{env}" unless ENVIRONMENTS.include?(env)

    stack_name = "tarot-api-#{env}"
    puts "deploying infrastructure for #{stack_name}..."

    # select stack
    system("cd #{PULUMI_DIR} && pulumi stack select #{stack_name}")

    # set secrets if not already set
    unless system("cd #{PULUMI_DIR} && pulumi config get databasePassword > /dev/null 2>&1")
      Rake::Task["pulumi:set_secrets"].invoke(env)
    end

    # deploy infrastructure
    if system("cd #{PULUMI_DIR} && pulumi up --yes")
      puts "infrastructure deployment for #{env} completed successfully"
      # output stack info
      system("cd #{PULUMI_DIR} && pulumi stack output")
    else
      abort "error: infrastructure deployment for #{env} failed"
    end
  end

  desc "destroy infrastructure for an environment"
  task :destroy, [ :environment ] => :init do |t, args|
    env = args[:environment] || "preview"
    abort "invalid environment: #{env}" unless ENVIRONMENTS.include?(env)

    # prevent accidental production destruction
    if env == "production"
      print "warning: you are about to destroy the production environment. this cannot be undone.\nare you sure? (type 'yes' to confirm): "
      confirmation = STDIN.gets.chomp
      abort "destruction cancelled" unless confirmation.downcase == "yes"
    end

    stack_name = "tarot-api-#{env}"
    puts "destroying infrastructure for #{stack_name}..."

    # select stack
    system("cd #{PULUMI_DIR} && pulumi stack select #{stack_name}")

    # destroy infrastructure
    if system("cd #{PULUMI_DIR} && pulumi destroy --yes")
      puts "infrastructure for #{env} destroyed successfully"
    else
      abort "error: infrastructure destruction for #{env} failed"
    end
  end

  desc "create a preview environment for a branch/pr"
  task :create_preview, [ :name ] => :init do |t, args|
    name = args[:name]
    abort "error: preview name is required" unless name

    # sanitize name for use in resource names
    preview_name = name.gsub(/[^a-zA-Z0-9]/, "-").downcase

    # create stack if it doesn't exist
    stack_name = "tarot-api-preview-#{preview_name}"

    # check if stack exists
    stdout, stderr, status = Open3.capture3("cd #{PULUMI_DIR} && pulumi stack ls")

    unless stdout.include?(stack_name)
      puts "creating stack for preview #{preview_name}..."
      system("cd #{PULUMI_DIR} && pulumi stack init #{stack_name}")

      # configure stack
      system("cd #{PULUMI_DIR} && pulumi config set environment preview")
      system("cd #{PULUMI_DIR} && pulumi config set preview-name #{preview_name}")
      system("cd #{PULUMI_DIR} && pulumi config set aws:region mx-central-1")
      system("cd #{PULUMI_DIR} && pulumi config set enable-cost-saving true")
      system("cd #{PULUMI_DIR} && pulumi config set domain tarotapi.cards")

      puts "preview stack initialized"
    else
      puts "preview stack already exists"
      system("cd #{PULUMI_DIR} && pulumi stack select #{stack_name}")
    end

    # set secrets for preview
    Rake::Task["pulumi:set_secrets"].invoke("preview")

    # deploy preview infrastructure
    if system("cd #{PULUMI_DIR} && pulumi up --yes")
      puts "preview environment for #{preview_name} created successfully"
      # get the url
      stdout, stderr, status = Open3.capture3("cd #{PULUMI_DIR} && pulumi stack output apiDns")
      api_url = stdout.strip
      puts "preview url: https://#{api_url}"
      puts "run the following command to export the url for github actions:"
      puts "echo \"PREVIEW_URL=https://#{api_url}\" >> $GITHUB_ENV"
    else
      abort "error: preview environment creation failed"
    end
  end

  desc "delete a preview environment"
  task :delete_preview, [ :name ] => :init do |t, args|
    name = args[:name]
    abort "error: preview name is required" unless name

    # sanitize name
    preview_name = name.gsub(/[^a-zA-Z0-9]/, "-").downcase
    stack_name = "tarot-api-preview-#{preview_name}"

    # check if stack exists
    stdout, stderr, status = Open3.capture3("cd #{PULUMI_DIR} && pulumi stack ls")

    if stdout.include?(stack_name)
      puts "deleting preview environment #{preview_name}..."
      system("cd #{PULUMI_DIR} && pulumi stack select #{stack_name}")

      # destroy infrastructure
      if system("cd #{PULUMI_DIR} && pulumi destroy --yes")
        puts "preview environment for #{preview_name} destroyed successfully"

        # remove stack
        system("cd #{PULUMI_DIR} && pulumi stack rm #{stack_name} --yes")
      else
        abort "error: preview environment destruction failed"
      end
    else
      puts "preview environment #{preview_name} does not exist"
    end
  end

  desc "list all preview environments"
  task list_previews: :init do
    puts "listing preview environments..."

    # list stacks and filter previews
    stdout, stderr, status = Open3.capture3("cd #{PULUMI_DIR} && pulumi stack ls")
    previews = stdout.split("\n").select { |line| line.include?("tarot-api-preview-") }

    if previews.empty?
      puts "no preview environments found"
    else
      puts "preview environments:"
      previews.each do |preview|
        puts "  #{preview.strip}"
      end
    end
  end

  desc "cleanup inactive preview environments (used by github actions)"
  task cleanup_previews: :init do
    puts "cleaning up inactive preview environments..."

    # list stacks and filter previews
    stdout, stderr, status = Open3.capture3("cd #{PULUMI_DIR} && pulumi stack ls")
    previews = stdout.split("\n").select { |line| line.include?("tarot-api-preview-") }

    if previews.empty?
      puts "no preview environments to clean up"
    else
      puts "checking #{previews.size} preview environments..."

      previews.each do |preview|
        preview_name = preview.strip.gsub("tarot-api-preview-", "")

        # check last activity from stack history
        stdout, stderr, status = Open3.capture3("cd #{PULUMI_DIR} && pulumi stack select tarot-api-preview-#{preview_name} && pulumi stack history --json")

        if status.success?
          begin
            history = JSON.parse(stdout)
            last_update = Time.parse(history.first["timestamp"]) rescue Time.now

            # if last update was more than 3 days ago, consider it inactive
            if (Time.now - last_update) > (3 * 24 * 60 * 60)
              puts "preview environment #{preview_name} is inactive (last updated #{last_update})"
              Rake::Task["pulumi:delete_preview"].invoke(preview_name)
              Rake::Task["pulumi:delete_preview"].reenable
            else
              puts "preview environment #{preview_name} is active (last updated #{last_update})"
            end
          rescue => e
            puts "error parsing history for #{preview_name}: #{e.message}"
          end
        else
          puts "error getting history for #{preview_name}"
        end
      end
    end
  end

  desc "register the tarotapi.cards domain with AWS"
  task register_domain: :init do
    puts "starting domain registration process for tarotapi.cards..."

    # check if domain is already registered
    stdout, stderr, status = Open3.capture3("aws route53domains get-domain-detail --domain-name tarotapi.cards")

    if status.success?
      puts "domain tarotapi.cards is already registered with aws"
      return
    end

    puts "domain tarotapi.cards is not registered with aws"
    puts "starting registration process..."

    # get contact information
    puts "please provide contact information for domain registration:"
    print "first name: "
    first_name = STDIN.gets.chomp
    print "last name: "
    last_name = STDIN.gets.chomp
    print "email: "
    email = STDIN.gets.chomp
    print "phone number (e.g. +1.1234567890): "
    phone = STDIN.gets.chomp
    print "address line 1: "
    address1 = STDIN.gets.chomp
    print "city: "
    city = STDIN.gets.chomp
    print "state/province: "
    state = STDIN.gets.chomp
    print "country code (e.g. US): "
    country = STDIN.gets.chomp
    print "postal code: "
    postal_code = STDIN.gets.chomp

    # create contact json
    contact = {
      firstName: first_name,
      lastName: last_name,
      contactType: "PERSON",
      organizationName: "",
      addressLine1: address1,
      city: city,
      state: state,
      countryCode: country,
      zipCode: postal_code,
      phoneNumber: phone,
      email: email
    }.to_json

    # create temporary file for contact
    contact_file = Tempfile.new([ "contact", ".json" ])
    contact_file.write(contact)
    contact_file.close

    # check domain availability
    puts "checking domain availability..."
    stdout, stderr, status = Open3.capture3("aws route53domains check-domain-availability --domain-name tarotapi.cards")

    if status.success?
      result = JSON.parse(stdout)
      if result["Availability"] == "AVAILABLE"
        puts "domain tarotapi.cards is available for registration"

        # get domain price
        stdout, stderr, status = Open3.capture3("aws route53domains get-domain-pricing --domain-name tarotapi.cards --tld-name cards")

        if status.success?
          pricing = JSON.parse(stdout)
          reg_price = pricing["RegistrationPrice"]["Price"]
          renewal_price = pricing["RenewalPrice"]["Price"]
          puts "domain registration price: $#{reg_price} (renewal: $#{renewal_price})"

          print "do you want to proceed with registration? (yes/no): "
          confirm = STDIN.gets.chomp.downcase

          if confirm == "yes"
            puts "registering domain tarotapi.cards..."

            # register domain
            cmd = "aws route53domains register-domain --domain-name tarotapi.cards " \
                  "--duration-in-years 1 --auto-renew " \
                  "--admin-contact file://#{contact_file.path} " \
                  "--registrant-contact file://#{contact_file.path} " \
                  "--tech-contact file://#{contact_file.path} " \
                  "--privacy-protect-admin-contact " \
                  "--privacy-protect-registrant-contact " \
                  "--privacy-protect-tech-contact"

            puts "executing: #{cmd}"
            if system(cmd)
              puts "domain registration initiated successfully"
              puts "note: domain registration can take up to 3 days to complete"
              puts "you will receive an email with confirmation"
            else
              puts "error: domain registration failed"
            end
          else
            puts "domain registration cancelled"
          end
        else
          puts "error getting domain pricing: #{stderr}"
        end
      else
        puts "domain tarotapi.cards is not available for registration (status: #{result["Availability"]})"
      end
    else
      puts "error checking domain availability: #{stderr}"
    end

    # remove temporary file
    contact_file.unlink
  end

  desc "protect domain from accidental deletion"
  task protect_domain: :init do
    puts "protecting tarotapi.cards domain from accidental deletion..."

    # check if domain is registered with aws
    stdout, stderr, status = Open3.capture3("aws route53domains get-domain-detail --domain-name tarotapi.cards")

    unless status.success?
      puts "error: domain tarotapi.cards is not registered with aws"
      return
    end

    # enable domain lock
    puts "enabling domain lock..."
    system("aws route53domains enable-domain-transfer-lock --domain-name tarotapi.cards")

    # enable auto-renew
    puts "enabling auto-renew..."
    system("aws route53domains enable-domain-auto-renew --domain-name tarotapi.cards")

    # create iam policy to prevent hosted zone deletion
    policy_name = "prevent-tarotapi-domain-deletion"

    # check if policy exists
    stdout, stderr, status = Open3.capture3("aws iam list-policies --scope Local --query \"Policies[?PolicyName=='#{policy_name}'].Arn\" --output text")

    if stdout.strip.empty?
      puts "creating iam policy to prevent hosted zone deletion..."

      # get hosted zone id
      stdout, stderr, status = Open3.capture3("aws route53 list-hosted-zones-by-name --dns-name tarotapi.cards --query \"HostedZones[0].Id\" --output text")

      if status.success?
        zone_id = stdout.strip.gsub("/hostedzone/", "")

        policy_document = {
          Version: "2012-10-17",
          Statement: [
            {
              Effect: "Deny",
              Action: [
                "route53:DeleteHostedZone",
                "route53domains:DeleteDomain"
              ],
              Resource: [
                "arn:aws:route53:::hostedzone/#{zone_id}",
                "*"
              ]
            }
          ]
        }.to_json

        # create temporary file for policy
        policy_file = Tempfile.new([ "policy", ".json" ])
        policy_file.write(policy_document)
        policy_file.close

        # create policy
        system("aws iam create-policy --policy-name #{policy_name} --policy-document file://#{policy_file.path}")

        # remove temporary file
        policy_file.unlink

        puts "iam policy created successfully"
      else
        puts "error getting hosted zone id: #{stderr}"
      end
    else
      puts "iam policy to prevent hosted zone deletion already exists"
    end

    puts "domain protection enabled for tarotapi.cards"
  end

  desc "deploy to production (requires confirmation)"
  task deploy_production: :init do
    print "warning: you are about to deploy to production. are you sure? (type 'yes' to confirm): "
    confirmation = STDIN.gets.chomp
    abort "deployment cancelled" unless confirmation.downcase == "yes"

    Rake::Task["pulumi:deploy"].invoke("production")
  end

  desc "output stack information for an environment"
  task :info, [ :environment ] => :init do |t, args|
    env = args[:environment] || "staging"
    abort "invalid environment: #{env}" unless ENVIRONMENTS.include?(env)

    stack_name = "tarot-api-#{env}"
    puts "getting information for #{stack_name} stack..."

    # select stack
    system("cd #{PULUMI_DIR} && pulumi stack select #{stack_name}")

    # get outputs
    system("cd #{PULUMI_DIR} && pulumi stack output")
  end

  desc "backup pulumi state for all stacks"
  task backup_state: :ensure_installed do
    puts "backing up pulumi state..."

    # create backup directory if it doesn't exist
    backup_dir = File.join(Rails.root, "backups", "pulumi")
    FileUtils.mkdir_p(backup_dir)

    # create timestamp for filename
    timestamp = Time.now.strftime("%Y%m%d%H%M%S")
    backup_file = File.join(backup_dir, "pulumi-state-#{timestamp}.tar.gz")

    # check if we're using s3 backend
    stdout, stderr, status = Open3.capture3("pulumi whoami")
    is_s3_backend = stdout.strip.start_with?("s3://")

    if is_s3_backend
      # get s3 bucket name
      bucket_name = stdout.strip.sub("s3://", "")
      puts "backing up state from s3 bucket: #{bucket_name}"

      # create temporary directory for downloading state
      temp_dir = File.join(Rails.root, "tmp", "pulumi-state-backup")
      FileUtils.rm_rf(temp_dir) if Dir.exist?(temp_dir)
      FileUtils.mkdir_p(temp_dir)

      # download state files from s3
      system("aws s3 sync s3://#{bucket_name} #{temp_dir}")

      # create tarball
      system("tar -czf #{backup_file} -C #{temp_dir} .")

      # clean up temp directory
      FileUtils.rm_rf(temp_dir)
    else
      # local backend - backup .pulumi directory
      pulumi_home = ENV["PULUMI_HOME"] || File.join(Dir.home, ".pulumi")
      if Dir.exist?(pulumi_home)
        system("tar -czf #{backup_file} -C #{File.dirname(pulumi_home)} #{File.basename(pulumi_home)}")
      else
        puts "warning: couldn't find pulumi home directory at #{pulumi_home}"
        abort "backup failed"
      end
    end

    if File.exist?(backup_file)
      puts "backup created: #{backup_file}"
      puts "backup size: #{File.size(backup_file) / 1024.0 / 1024.0} MB"
    else
      puts "warning: backup file was not created"
    end
  end

  desc "restore pulumi state from backup"
  task :restore_state, [ :backup_file ] => :ensure_installed do |t, args|
    backup_file = args[:backup_file]
    abort "error: backup file path is required" unless backup_file
    abort "error: backup file not found: #{backup_file}" unless File.exist?(backup_file)

    puts "restoring pulumi state from #{backup_file}..."

    # check if we're using s3 backend
    stdout, stderr, status = Open3.capture3("pulumi whoami")
    is_s3_backend = stdout.strip.start_with?("s3://")

    if is_s3_backend
      # get s3 bucket name
      bucket_name = stdout.strip.sub("s3://", "")
      puts "restoring state to s3 bucket: #{bucket_name}"

      # create temporary directory for extracting backup
      temp_dir = File.join(Rails.root, "tmp", "pulumi-state-restore")
      FileUtils.rm_rf(temp_dir) if Dir.exist?(temp_dir)
      FileUtils.mkdir_p(temp_dir)

      # extract backup
      system("tar -xzf #{backup_file} -C #{temp_dir}")

      # confirm before uploading
      print "warning: this will overwrite all state in the s3 bucket #{bucket_name}. continue? (yes/no): "
      response = STDIN.gets.chomp.downcase
      abort "restore cancelled" unless response == "yes"

      # upload to s3
      system("aws s3 sync #{temp_dir} s3://#{bucket_name}")

      # clean up temp directory
      FileUtils.rm_rf(temp_dir)
    else
      # local backend - restore .pulumi directory
      pulumi_home = ENV["PULUMI_HOME"] || File.join(Dir.home, ".pulumi")

      # confirm before overwriting
      print "warning: this will overwrite your local pulumi state at #{pulumi_home}. continue? (yes/no): "
      response = STDIN.gets.chomp.downcase
      abort "restore cancelled" unless response == "yes"

      # backup existing state first
      if Dir.exist?(pulumi_home)
        backup_timestamp = Time.now.strftime("%Y%m%d%H%M%S")
        system("mv #{pulumi_home} #{pulumi_home}.bak.#{backup_timestamp}")
        puts "existing state backed up to #{pulumi_home}.bak.#{backup_timestamp}"
      end

      # extract backup
      system("tar -xzf #{backup_file} -C #{File.dirname(pulumi_home)}")
    end

    puts "pulumi state restored successfully"
  end

  desc "store domain registration information in AWS Parameter Store for later use"
  task :store_domain_info => :ensure_installed do
    puts "This task will securely store domain registration information in AWS Parameter Store"
    puts "This information will be used when registering the domain automatically"
    
    # Create parameter path
    param_path_prefix = "/tarot-api/domain/"
    
    # Check if AWS CLI is configured
    unless system("aws sts get-caller-identity > /dev/null 2>&1")
      abort "Error: AWS CLI is not configured. Please run 'aws configure' first."
    end
    
    # Collect registration information
    puts "Please provide contact information for domain registration:"
    print "First name: "
    first_name = STDIN.gets.chomp
    print "Last name: "
    last_name = STDIN.gets.chomp
    print "Email: "
    email = STDIN.gets.chomp
    print "Phone number (e.g. +1.1234567890): "
    phone = STDIN.gets.chomp
    print "Address line 1: "
    address1 = STDIN.gets.chomp
    print "City: "
    city = STDIN.gets.chomp
    print "State/Province: "
    state = STDIN.gets.chomp
    print "Country code (e.g. US): "
    country = STDIN.gets.chomp
    print "Postal code: "
    postal_code = STDIN.gets.chomp
    
    # Store information in AWS Parameter Store (securely)
    puts "Storing information in AWS Parameter Store..."
    
    params = [
      { name: "firstName", value: first_name },
      { name: "lastName", value: last_name },
      { name: "email", value: email },
      { name: "phoneNumber", value: phone },
      { name: "addressLine1", value: address1 },
      { name: "city", value: city },
      { name: "state", value: state },
      { name: "countryCode", value: country },
      { name: "postalCode", value: postal_code }
    ]
    
    params.each do |param|
      full_path = "#{param_path_prefix}#{param[:name]}"
      system("aws ssm put-parameter --name \"#{full_path}\" --value \"#{param[:value]}\" --type SecureString --overwrite")
    end
    
    puts "Domain registration information stored securely."
    puts "When you're ready to register the domain, run: rake pulumi:register_domain_auto"
  end
  
  desc "automatically register domain using stored information"
  task :register_domain_auto => :init do
    puts "Registering tarotapi.cards domain using stored registration information..."
    
    # Parameter path
    param_path_prefix = "/tarot-api/domain/"
    
    # Check if domain is already registered
    stdout, stderr, status = Open3.capture3("aws route53domains get-domain-detail --domain-name tarotapi.cards")
    
    if status.success?
      puts "Domain tarotapi.cards is already registered with AWS"
      return
    end
    
    # Retrieve stored parameters
    contact_info = {}
    
    params = %w[firstName lastName email phoneNumber addressLine1 city state countryCode postalCode]
    
    params.each do |param|
      full_path = "#{param_path_prefix}#{param}"
      stdout, stderr, status = Open3.capture3("aws ssm get-parameter --name \"#{full_path}\" --with-decryption")
      
      if status.success?
        value = JSON.parse(stdout)["Parameter"]["Value"]
        contact_info[param] = value
      else
        abort "Error: Could not retrieve parameter #{param}. Please run 'rake pulumi:store_domain_info' first."
      end
    end
    
    # Check domain availability
    puts "Checking domain availability..."
    stdout, stderr, status = Open3.capture3("aws route53domains check-domain-availability --domain-name tarotapi.cards")
    
    if status.success?
      result = JSON.parse(stdout)
      if result["Availability"] == "AVAILABLE"
        puts "Domain tarotapi.cards is available for registration"
        
        # Get domain price
        stdout, stderr, status = Open3.capture3("aws route53domains get-domain-pricing --domain-name tarotapi.cards --tld-name cards")
        
        if status.success?
          pricing = JSON.parse(stdout)
          reg_price = pricing["RegistrationPrice"]["Price"]
          renewal_price = pricing["RenewalPrice"]["Price"]
          puts "Domain registration price: $#{reg_price} (renewal: $#{renewal_price})"
          
          print "Do you want to proceed with automatic registration? (yes/no): "
          confirm = STDIN.gets.chomp.downcase
          
          if confirm == "yes"
            # Create contact JSON
            contact = {
              firstName: contact_info["firstName"],
              lastName: contact_info["lastName"],
              contactType: "PERSON",
              organizationName: "",
              addressLine1: contact_info["addressLine1"],
              city: contact_info["city"],
              state: contact_info["state"],
              countryCode: contact_info["countryCode"],
              zipCode: contact_info["postalCode"],
              phoneNumber: contact_info["phoneNumber"],
              email: contact_info["email"]
            }.to_json
            
            # Create temporary file for contact
            contact_file = Tempfile.new(["contact", ".json"])
            contact_file.write(contact)
            contact_file.close
            
            puts "Registering domain tarotapi.cards..."
            
            # Register domain
            cmd = "aws route53domains register-domain --domain-name tarotapi.cards " \
                  "--duration-in-years 1 --auto-renew " \
                  "--admin-contact file://#{contact_file.path} " \
                  "--registrant-contact file://#{contact_file.path} " \
                  "--tech-contact file://#{contact_file.path} " \
                  "--privacy-protect-admin-contact " \
                  "--privacy-protect-registrant-contact " \
                  "--privacy-protect-tech-contact"
            
            puts "Executing: #{cmd}"
            if system(cmd)
              puts "Domain registration initiated successfully"
              puts "Note: Domain registration can take up to 3 days to complete"
              puts "You will receive an email with confirmation"
              
              # After successful registration, automatically protect the domain
              puts "Sleeping for 60 seconds to allow registration to process..."
              sleep(60)
              Rake::Task["pulumi:protect_domain"].invoke
            else
              puts "Error: Domain registration failed"
            end
            
            # Remove temporary file
            contact_file.unlink
          else
            puts "Domain registration cancelled"
          end
        else
          puts "Error getting domain pricing: #{stderr}"
        end
      else
        puts "Domain tarotapi.cards is not available for registration (status: #{result["Availability"]})"
      end
    else
      puts "Error checking domain availability: #{stderr}"
    end
  end

  desc "register domain fully automated using existing contact information from AWS"
  task :register_domain_fully_automated => :init do
    puts "Starting fully automated domain registration for tarotapi.cards..."
    
    # Check if domain is already registered
    stdout, stderr, status = Open3.capture3("aws route53domains get-domain-detail --domain-name tarotapi.cards")
    
    if status.success?
      puts "Domain tarotapi.cards is already registered with AWS"
      return
    end
    
    # Find existing domains owned by this AWS account
    puts "Searching for existing domains to reuse contact information..."
    stdout, stderr, status = Open3.capture3("aws route53domains list-domains")
    
    if !status.success? || stdout.strip.empty? || stdout.include?("[]")
      puts "No existing domains found in your AWS account. Cannot reuse contact information."
      puts "Falling back to manual registration method..."
      Rake::Task["pulumi:register_domain"].invoke
      return
    end
    
    # Parse domain list result
    begin
      domains = JSON.parse(stdout)["Domains"]
      if domains.empty?
        puts "No existing domains found in your AWS account. Cannot reuse contact information."
        puts "Falling back to manual registration method..."
        Rake::Task["pulumi:register_domain"].invoke
        return
      end
      
      # Use the first domain as source for contact information
      source_domain = domains.first["DomainName"]
      puts "Found existing domain: #{source_domain}"
      puts "Will reuse contact information from this domain"
      
      # Get detailed information about the source domain
      stdout, stderr, status = Open3.capture3("aws route53domains get-domain-detail --domain-name #{source_domain}")
      
      if !status.success?
        puts "Failed to get details for domain #{source_domain}"
        puts "Falling back to manual registration method..."
        Rake::Task["pulumi:register_domain"].invoke
        return
      end
      
      domain_details = JSON.parse(stdout)
      
      # Check domain availability
      puts "Checking availability of tarotapi.cards..."
      stdout, stderr, status = Open3.capture3("aws route53domains check-domain-availability --domain-name tarotapi.cards")
      
      if !status.success?
        puts "Failed to check domain availability: #{stderr}"
        return
      end
      
      availability_result = JSON.parse(stdout)
      if availability_result["Availability"] != "AVAILABLE"
        puts "Domain tarotapi.cards is not available for registration (status: #{availability_result["Availability"]})"
        return
      end
      
      puts "Domain tarotapi.cards is available for registration"
      
      # Get domain pricing
      stdout, stderr, status = Open3.capture3("aws route53domains get-domain-pricing --domain-name tarotapi.cards --tld-name cards")
      
      if !status.success?
        puts "Failed to get domain pricing: #{stderr}"
        return
      end
      
      pricing = JSON.parse(stdout)
      reg_price = pricing["RegistrationPrice"]["Price"]
      renewal_price = pricing["RenewalPrice"]["Price"]
      puts "Domain registration price: $#{reg_price} (renewal: $#{renewal_price})"
      
      print "Do you want to proceed with automatic registration using existing contact information? (yes/no): "
      confirm = STDIN.gets.chomp.downcase
      
      if confirm != "yes"
        puts "Domain registration cancelled"
        return
      end
      
      # Create temporary JSON files for contact information
      admin_contact_file = Tempfile.new(["admin-contact", ".json"])
      registrant_contact_file = Tempfile.new(["registrant-contact", ".json"])
      tech_contact_file = Tempfile.new(["tech-contact", ".json"])
      
      begin
        # Extract and save contact information from source domain
        admin_contact_file.write(domain_details["AdminContact"].to_json)
        registrant_contact_file.write(domain_details["RegistrantContact"].to_json)
        tech_contact_file.write(domain_details["TechContact"].to_json)
        
        admin_contact_file.close
        registrant_contact_file.close
        tech_contact_file.close
        
        # Register domain with existing contact information
        puts "Registering domain tarotapi.cards with contact information from #{source_domain}..."
        
        cmd = "aws route53domains register-domain " \
              "--domain-name tarotapi.cards " \
              "--duration-in-years 1 " \
              "--auto-renew " \
              "--admin-contact file://#{admin_contact_file.path} " \
              "--registrant-contact file://#{registrant_contact_file.path} " \
              "--tech-contact file://#{tech_contact_file.path} " \
              "--privacy-protect-admin-contact " \
              "--privacy-protect-registrant-contact " \
              "--privacy-protect-tech-contact"
        
        puts "Executing: #{cmd}"
        if system(cmd)
          puts "Domain registration initiated successfully"
          puts "Note: Domain registration can take up to 3 days to complete"
          
          # After successful registration, automatically protect the domain
          puts "Waiting for 60 seconds to allow registration to process..."
          sleep(60)
          Rake::Task["pulumi:protect_domain"].invoke
        else
          puts "Error: Domain registration failed"
        end
      ensure
        # Clean up temporary files
        admin_contact_file.unlink
        registrant_contact_file.unlink
        tech_contact_file.unlink
      end
    rescue JSON::ParserError => e
      puts "Error parsing domain information: #{e.message}"
      puts "Falling back to manual registration method..."
      Rake::Task["pulumi:register_domain"].invoke
    end
  end

  desc "register alternative TLD (tarot.cards) using existing contact information"
  task :register_alt_domain => :init do
    puts "Starting registration for alternative domain tarot.cards..."
    
    # Check if domain is already registered
    stdout, stderr, status = Open3.capture3("aws route53domains get-domain-detail --domain-name tarot.cards")
    
    if status.success?
      puts "Domain tarot.cards is already registered with AWS"
      return
    end
    
    # Find existing domains owned by this AWS account
    puts "Searching for existing domains to reuse contact information..."
    stdout, stderr, status = Open3.capture3("aws route53domains list-domains")
    
    if !status.success? || stdout.strip.empty? || stdout.include?("[]")
      puts "No existing domains found in your AWS account. Cannot reuse contact information."
      puts "Please register at least one domain manually first."
      return
    end
    
    # Parse domain list result
    begin
      domains = JSON.parse(stdout)["Domains"]
      if domains.empty?
        puts "No existing domains found in your AWS account. Cannot reuse contact information."
        puts "Please register at least one domain manually first."
        return
      end
      
      # Use the first domain as source for contact information
      source_domain = domains.first["DomainName"]
      puts "Found existing domain: #{source_domain}"
      puts "Will reuse contact information from this domain"
      
      # Get detailed information about the source domain
      stdout, stderr, status = Open3.capture3("aws route53domains get-domain-detail --domain-name #{source_domain}")
      
      if !status.success?
        puts "Failed to get details for domain #{source_domain}"
        return
      end
      
      domain_details = JSON.parse(stdout)
      
      # Check domain availability
      puts "Checking availability of tarot.cards..."
      stdout, stderr, status = Open3.capture3("aws route53domains check-domain-availability --domain-name tarot.cards")
      
      if !status.success?
        puts "Failed to check domain availability: #{stderr}"
        return
      end
      
      availability_result = JSON.parse(stdout)
      if availability_result["Availability"] != "AVAILABLE"
        puts "Domain tarot.cards is not available for registration (status: #{availability_result["Availability"]})"
        return
      end
      
      puts "Domain tarot.cards is available for registration"
      
      # Get domain pricing
      stdout, stderr, status = Open3.capture3("aws route53domains get-domain-pricing --domain-name tarot.cards --tld-name cards")
      
      if !status.success?
        puts "Failed to get domain pricing: #{stderr}"
        return
      end
      
      pricing = JSON.parse(stdout)
      reg_price = pricing["RegistrationPrice"]["Price"]
      renewal_price = pricing["RenewalPrice"]["Price"]
      puts "Domain registration price: $#{reg_price} (renewal: $#{renewal_price})"
      
      print "Do you want to proceed with automatic registration of tarot.cards? (yes/no): "
      confirm = STDIN.gets.chomp.downcase
      
      if confirm != "yes"
        puts "Domain registration cancelled"
        return
      end
      
      # Create temporary JSON files for contact information
      admin_contact_file = Tempfile.new(["admin-contact", ".json"])
      registrant_contact_file = Tempfile.new(["registrant-contact", ".json"])
      tech_contact_file = Tempfile.new(["tech-contact", ".json"])
      
      begin
        # Extract and save contact information from source domain
        admin_contact_file.write(domain_details["AdminContact"].to_json)
        registrant_contact_file.write(domain_details["RegistrantContact"].to_json)
        tech_contact_file.write(domain_details["TechContact"].to_json)
        
        admin_contact_file.close
        registrant_contact_file.close
        tech_contact_file.close
        
        # Register domain with existing contact information
        puts "Registering domain tarot.cards with contact information from #{source_domain}..."
        
        cmd = "aws route53domains register-domain " \
              "--domain-name tarot.cards " \
              "--duration-in-years 1 " \
              "--auto-renew " \
              "--admin-contact file://#{admin_contact_file.path} " \
              "--registrant-contact file://#{registrant_contact_file.path} " \
              "--tech-contact file://#{tech_contact_file.path} " \
              "--privacy-protect-admin-contact " \
              "--privacy-protect-registrant-contact " \
              "--privacy-protect-tech-contact"
        
        puts "Executing: #{cmd}"
        if system(cmd)
          puts "Domain registration initiated successfully"
          puts "Note: Domain registration can take up to 3 days to complete"
          
          # After successful registration, automatically protect the domain
          puts "Waiting for 60 seconds to allow registration to process..."
          sleep(60)
          Rake::Task["pulumi:protect_alt_domain"].invoke
        else
          puts "Error: Domain registration failed"
        end
      ensure
        # Clean up temporary files
        admin_contact_file.unlink
        registrant_contact_file.unlink
        tech_contact_file.unlink
      end
    rescue JSON::ParserError => e
      puts "Error parsing domain information: #{e.message}"
    end
  end
  
  desc "protect tarot.cards domain from accidental deletion"
  task :protect_alt_domain => :init do
    puts "protecting tarot.cards domain from accidental deletion..."

    # check if domain is registered with aws
    stdout, stderr, status = Open3.capture3("aws route53domains get-domain-detail --domain-name tarot.cards")

    unless status.success?
      puts "error: domain tarot.cards is not registered with aws"
      return
    end

    # enable domain lock
    puts "enabling domain lock..."
    system("aws route53domains enable-domain-transfer-lock --domain-name tarot.cards")

    # enable auto-renew
    puts "enabling auto-renew..."
    system("aws route53domains enable-domain-auto-renew --domain-name tarot.cards")

    # create iam policy to prevent hosted zone deletion
    policy_name = "prevent-tarot-cards-domain-deletion"

    # check if policy exists
    stdout, stderr, status = Open3.capture3("aws iam list-policies --scope Local --query \"Policies[?PolicyName=='#{policy_name}'].Arn\" --output text")

    if stdout.strip.empty?
      puts "creating iam policy to prevent hosted zone deletion..."

      # get hosted zone id
      stdout, stderr, status = Open3.capture3("aws route53 list-hosted-zones-by-name --dns-name tarot.cards --query \"HostedZones[0].Id\" --output text")

      if status.success?
        zone_id = stdout.strip.gsub("/hostedzone/", "")

        policy_document = {
          Version: "2012-10-17",
          Statement: [
            {
              Effect: "Deny",
              Action: [
                "route53:DeleteHostedZone",
                "route53domains:DeleteDomain"
              ],
              Resource: [
                "arn:aws:route53:::hostedzone/#{zone_id}",
                "*"
              ]
            }
          ]
        }.to_json

        # create temporary file for policy
        policy_file = Tempfile.new([ "policy", ".json" ])
        policy_file.write(policy_document)
        policy_file.close

        # create policy
        system("aws iam create-policy --policy-name #{policy_name} --policy-document file://#{policy_file.path}")

        # remove temporary file
        policy_file.unlink

        puts "iam policy created successfully"
      else
        puts "error getting hosted zone id: #{stderr}"
      end
    else
      puts "iam policy to prevent hosted zone deletion already exists"
    end

    puts "domain protection enabled for tarot.cards"
  end
end
