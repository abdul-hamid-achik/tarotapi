namespace :pulumi do
  require "fileutils"
  require "json"
  require "yaml"
  require "open3"

  # infrastructure directory
  PULUMI_DIR = File.join(Rails.root, "infrastructure")
  ENVIRONMENTS = %w[production staging]

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

  desc "initialize pulumi project"
  task init: :ensure_installed do
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

    # Login to Pulumi Cloud using access token
    if ENV["PULUMI_PERSONAL_ACCESS_TOKEN"]
      puts "logging in to Pulumi Cloud..."
      system("pulumi login")
      puts "logged in to Pulumi Cloud successfully"
    else
      abort "error: PULUMI_PERSONAL_ACCESS_TOKEN environment variable is not set. Please set it to use Pulumi Cloud."
    end

    # create stacks for each environment if they don't exist
    ENVIRONMENTS.each do |env|
      stack_name = env

      # check if stack exists
      stdout, stderr, status = Open3.capture3("cd #{PULUMI_DIR} && pulumi stack ls")

      unless stdout.include?(stack_name)
        puts "creating stack for #{env} environment..."
        system("cd #{PULUMI_DIR} && pulumi stack init #{stack_name}")

        # configure stack
        system("cd #{PULUMI_DIR} && pulumi config set environment #{env}")
        system("cd #{PULUMI_DIR} && pulumi config set aws:region #{ENV['AWS_DEFAULT_REGION'] || 'mx-central-1'}")

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
    abort "invalid environment: #{env}" unless ENVIRONMENTS.include?(env) || env.start_with?("preview-")

    stack_name = env
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
    abort "invalid environment: #{env}" unless ENVIRONMENTS.include?(env) || env.start_with?("preview-")

    stack_name = env
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
    abort "invalid environment: #{env}" unless ENVIRONMENTS.include?(env) || env.start_with?("preview-")

    # prevent accidental production destruction
    if env == "production"
      print "warning: you are about to destroy the production environment. this cannot be undone.\nare you sure? (type 'yes' to confirm): "
      confirmation = STDIN.gets.chomp
      abort "destruction cancelled" unless confirmation.downcase == "yes"
    end

    stack_name = env
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
    stack_name = "preview-#{preview_name}"

    # check if stack exists
    stdout, stderr, status = Open3.capture3("cd #{PULUMI_DIR} && pulumi stack ls")

    unless stdout.include?(stack_name)
      puts "creating stack for preview #{preview_name}..."
      system("cd #{PULUMI_DIR} && pulumi stack init #{stack_name}")

      # configure stack
      system("cd #{PULUMI_DIR} && pulumi config set environment preview")
      system("cd #{PULUMI_DIR} && pulumi config set preview-name #{preview_name}")
      system("cd #{PULUMI_DIR} && pulumi config set aws:region #{ENV['AWS_DEFAULT_REGION'] || 'mx-central-1'}")
      system("cd #{PULUMI_DIR} && pulumi config set enable-cost-saving true")
      system("cd #{PULUMI_DIR} && pulumi config set domain tarotapi.cards")

      puts "preview stack initialized"
    else
      puts "preview stack already exists"
      system("cd #{PULUMI_DIR} && pulumi stack select #{stack_name}")
    end

    # set secrets for preview
    Rake::Task["pulumi:set_secrets"].invoke(stack_name)

    # deploy preview infrastructure
    if system("cd #{PULUMI_DIR} && pulumi up --yes")
      puts "preview environment for #{preview_name} created successfully"
      # get the url
      stdout, stderr, status = Open3.capture3("cd #{PULUMI_DIR} && pulumi stack output apiDns")
      api_url = stdout.strip
      puts "preview url: https://#{api_url}"
      puts "run the following command to export the url for github actions:"
      puts "export PREVIEW_URL=https://#{api_url}"
    else
      abort "error: preview environment creation failed"
    end
  end

  desc "delete a preview environment"
  task :delete_preview, [ :name ] => :destroy do |t, args|
    name = args[:name]
    abort "error: preview name is required" unless name

    # delete the preview environment
    Rake::Task["pulumi:destroy"].invoke("preview-#{name.gsub(/[^a-zA-Z0-9]/, "-").downcase}")
  end

  desc "list all preview environments"
  task list_previews: :ensure_installed do
    puts "listing preview environments..."
    stdout, stderr, status = Open3.capture3("cd #{PULUMI_DIR} && pulumi stack ls")
    if status.success?
      preview_stacks = stdout.split("\n").select { |line| line.include?("preview-") }
      if preview_stacks.empty?
        puts "no preview environments found"
      else
        puts "preview environments:"
        preview_stacks.each do |stack|
          puts "  - #{stack}"
        end
      end
    else
      puts "error listing stacks: #{stderr}"
    end
  end

  desc "clean up inactive preview environments"
  task cleanup_previews: :ensure_installed do
    puts "looking for inactive preview environments..."
    
    # Get all preview stacks
    stdout, stderr, status = Open3.capture3("cd #{PULUMI_DIR} && pulumi stack ls")
    if status.success?
      preview_stacks = stdout.split("\n").select { |line| line.include?("preview-") }
      
      if preview_stacks.empty?
        puts "no preview environments found to clean up"
      else
        puts "found #{preview_stacks.size} preview environments"
        
        # Check last update time for each stack
        preview_stacks.each do |stack_line|
          stack_name = stack_line.strip.split(/\s+/).first
          
          puts "checking activity for #{stack_name}..."
          
          # Get the last update time
          update_stdout, update_stderr, update_status = Open3.capture3("cd #{PULUMI_DIR} && pulumi stack history #{stack_name} --json")
          
          if update_status.success?
            begin
              history = JSON.parse(update_stdout)
              if history.is_a?(Array) && !history.empty?
                last_update = Time.parse(history.first["timestamp"])
                days_since_update = (Time.now - last_update) / (24 * 60 * 60)
                
                puts "  last updated: #{last_update} (#{days_since_update.round(1)} days ago)"
                
                # If older than 7 days, destroy it
                if days_since_update > 7
                  puts "  environment inactive for over 7 days, cleaning up..."
                  
                  # Select and destroy the stack
                  system("cd #{PULUMI_DIR} && pulumi stack select #{stack_name}")
                  if system("cd #{PULUMI_DIR} && pulumi destroy --yes")
                    puts "  infrastructure destroyed successfully"
                    
                    # Remove the stack
                    if system("cd #{PULUMI_DIR} && pulumi stack rm --yes #{stack_name}")
                      puts "  stack removed successfully"
                    else
                      puts "  warning: failed to remove stack"
                    end
                  else
                    puts "  warning: failed to destroy infrastructure"
                  end
                else
                  puts "  environment is still active, skipping cleanup"
                end
              else
                puts "  no history found, skipping"
              end
            rescue => e
              puts "  error parsing history: #{e.message}"
            end
          else
            puts "  error getting history: #{update_stderr}"
          end
        end
      end
    else
      puts "error listing stacks: #{stderr}"
    end
  end

  desc "special deployment for production, includes staging test first"
  task deploy_production: :init do
    puts "deploying to production with staging validation..."
    
    # First, deploy to staging
    puts "deploying to staging for validation..."
    Rake::Task["pulumi:deploy"].invoke("staging")
    
    # Ask for confirmation before proceeding to production
    print "staging deployment complete. do you want to proceed with production deployment? (yes/no): "
    confirmation = STDIN.gets.chomp
    
    if confirmation.downcase == "yes"
      puts "proceeding with production deployment..."
      Rake::Task["pulumi:deploy"].reenable
      Rake::Task["pulumi:deploy"].invoke("production")
      puts "production deployment complete"
    else
      puts "production deployment cancelled"
    end
  end

  desc "display information about a stack"
  task :info, [ :environment ] => :ensure_installed do |t, args|
    env = args[:environment] || "staging"
    abort "invalid environment: #{env}" unless ENVIRONMENTS.include?(env) || env.start_with?("preview-")

    stack_name = env
    puts "stack information for #{stack_name}:"
    
    # Select the stack
    system("cd #{PULUMI_DIR} && pulumi stack select #{stack_name}")
    
    # Show stack info
    system("cd #{PULUMI_DIR} && pulumi stack")
    
    # Show outputs
    puts "\nstack outputs:"
    system("cd #{PULUMI_DIR} && pulumi stack output")
  end

  desc "manage pulumi state (backup or restore)"
  task :manage_state, [:operation, :file] => :ensure_installed do |t, args|
    operation = args[:operation] || "backup"
    file = args[:file]

    case operation.downcase
    when "backup"
      puts "backing up pulumi state..."
      Rake::Task["pulumi:backup_state"].invoke
    when "restore"
      abort "Error: Backup file path is required for restore operation" unless file
      puts "restoring pulumi state from #{file}..."
      Rake::Task["pulumi:restore_state"].invoke(file)
    else
      abort "Error: Unknown operation '#{operation}'. Please use 'backup' or 'restore'."
    end
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

    # check if we're using Pulumi Cloud
    stdout, stderr, status = Open3.capture3("pulumi whoami")
    is_cloud_backend = !stdout.strip.start_with?("s3://") && !stdout.strip.start_with?("file://")
    
    if is_cloud_backend
      puts "Backing up state from Pulumi Cloud..."
      
      # create temporary directory for storing exported state
      temp_dir = File.join(Rails.root, "tmp", "pulumi-state-backup")
      FileUtils.rm_rf(temp_dir) if Dir.exist?(temp_dir)
      FileUtils.mkdir_p(temp_dir)
      
      # get list of stacks
      stdout, stderr, status = Open3.capture3("cd #{PULUMI_DIR} && pulumi stack ls --json")
      
      if status.success?
        stacks = JSON.parse(stdout)
        puts "Found #{stacks.size} stacks to backup"
        
        stacks.each do |stack|
          stack_name = stack["name"]
          puts "Exporting stack: #{stack_name}"
          
          # export stack state
          stack_file = File.join(temp_dir, "#{stack_name}.json")
          system("cd #{PULUMI_DIR} && pulumi stack export --stack=#{stack_name} > #{stack_file}")
          
          if File.exist?(stack_file)
            puts "  Exported #{stack_name} (#{File.size(stack_file) / 1024.0} KB)"
          else
            puts "  Warning: Failed to export #{stack_name}"
          end
        end
        
        # create tarball
        system("tar -czf #{backup_file} -C #{temp_dir} .")
        
        # clean up temp directory
        FileUtils.rm_rf(temp_dir)
      else
        puts "Error listing stacks: #{stderr}"
        abort "Backup failed"
      end
    else
      # local backend - backup .pulumi directory
      pulumi_home = ENV["PULUMI_HOME"] || File.join(Dir.home, ".pulumi")
      if Dir.exist?(pulumi_home)
        system("tar -czf #{backup_file} -C #{File.dirname(pulumi_home)} #{File.basename(pulumi_home)}")
      else
        puts "Warning: Couldn't find pulumi home directory at #{pulumi_home}"
        abort "Backup failed"
      end
    end

    if File.exist?(backup_file)
      puts "Backup created: #{backup_file}"
      puts "Backup size: #{File.size(backup_file) / 1024.0 / 1024.0} MB"
    else
      puts "Warning: Backup file was not created"
    end
  end

  desc "restore pulumi state from backup"
  task :restore_state, [ :backup_file ] => :ensure_installed do |t, args|
    backup_file = args[:backup_file]
    abort "Error: Backup file path is required" unless backup_file
    abort "Error: Backup file not found: #{backup_file}" unless File.exist?(backup_file)

    puts "Restoring pulumi state from #{backup_file}..."

    # check if we're using Pulumi Cloud
    stdout, stderr, status = Open3.capture3("pulumi whoami")
    is_cloud_backend = !stdout.strip.start_with?("s3://") && !stdout.strip.start_with?("file://")

    if is_cloud_backend
      puts "Restoring state to Pulumi Cloud..."

      # create temporary directory for extracting backup
      temp_dir = File.join(Rails.root, "tmp", "pulumi-state-restore")
      FileUtils.rm_rf(temp_dir) if Dir.exist?(temp_dir)
      FileUtils.mkdir_p(temp_dir)

      # extract backup
      system("tar -xzf #{backup_file} -C #{temp_dir}")

      # confirm before restoring
      print "Warning: This will overwrite stack state in Pulumi Cloud. Continue? (yes/no): "
      response = STDIN.gets.chomp.downcase
      abort "Restore cancelled" unless response == "yes"

      # find all JSON files (stack exports)
      stack_files = Dir.glob(File.join(temp_dir, "*.json"))
      
      puts "Found #{stack_files.size} stacks to restore"
      
      stack_files.each do |stack_file|
        stack_name = File.basename(stack_file, ".json")
        puts "Importing stack: #{stack_name}"
        
        # check if stack exists
        stack_exists = system("cd #{PULUMI_DIR} && pulumi stack ls | grep -q #{stack_name}")
        
        unless stack_exists
          puts "  Stack doesn't exist, creating it first..."
          system("cd #{PULUMI_DIR} && pulumi stack init #{stack_name}")
        end
        
        # import stack state
        if system("cd #{PULUMI_DIR} && pulumi stack import --stack=#{stack_name} --file=#{stack_file}")
          puts "  Successfully imported #{stack_name}"
        else
          puts "  Failed to import #{stack_name}"
        end
      end

      # clean up temp directory
      FileUtils.rm_rf(temp_dir)
    else
      # local backend - restore .pulumi directory
      pulumi_home = ENV["PULUMI_HOME"] || File.join(Dir.home, ".pulumi")

      # confirm before overwriting
      print "Warning: This will overwrite your local pulumi state at #{pulumi_home}. Continue? (yes/no): "
      response = STDIN.gets.chomp.downcase
      abort "Restore cancelled" unless response == "yes"

      # backup existing state first
      if Dir.exist?(pulumi_home)
        backup_timestamp = Time.now.strftime("%Y%m%d%H%M%S")
        system("mv #{pulumi_home} #{pulumi_home}.bak.#{backup_timestamp}")
        puts "Existing state backed up to #{pulumi_home}.bak.#{backup_timestamp}"
      end

      # extract backup
      system("tar -xzf #{backup_file} -C #{File.dirname(pulumi_home)}")
    end

    puts "Pulumi state restored successfully"
  end

  desc "store domain registration information in AWS Parameter Store for later use"
  task store_domain_info: :ensure_installed do
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
  task register_domain_auto: :init do
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
            contact_file = Tempfile.new([ "contact", ".json" ])
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
  task register_domain_fully_automated: :init do
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
      admin_contact_file = Tempfile.new([ "admin-contact", ".json" ])
      registrant_contact_file = Tempfile.new([ "registrant-contact", ".json" ])
      tech_contact_file = Tempfile.new([ "tech-contact", ".json" ])

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
  task register_alt_domain: :init do
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
      admin_contact_file = Tempfile.new([ "admin-contact", ".json" ])
      registrant_contact_file = Tempfile.new([ "registrant-contact", ".json" ])
      tech_contact_file = Tempfile.new([ "tech-contact", ".json" ])

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
  task protect_alt_domain: :init do
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

  desc "Initialize infrastructure for both staging and production"
  task :init_all do
    puts Rainbow("Initializing Pulumi infrastructure for all environments").bright.green

    # Setup the S3 bucket for Pulumi state if needed
    Rake::Task["pulumi:init"].invoke

    # Initialize staging environment
    puts Rainbow("Initializing staging environment").yellow
    sh "pulumi stack select staging"
    Rake::Task["pulumi:set_secrets"].invoke("staging")

    # Initialize production environment
    puts Rainbow("Initializing production environment").yellow
    sh "pulumi stack select production"
    Rake::Task["pulumi:set_secrets"].invoke("production")

    puts Rainbow("Infrastructure initialization complete!").bright.green
    puts Rainbow("Next steps:").cyan
    puts Rainbow("  1. Run 'rake pulumi:deploy_all' to deploy all environments").cyan
    puts Rainbow("  2. Or run 'rake pulumi:deploy[staging]' to deploy only staging").cyan
  end

  desc "Deploy infrastructure to staging, then gradually to production (blue/green deployment)"
  task :deploy_all do
    puts Rainbow("Starting full deployment pipeline").bright.green

    # First deploy to staging
    puts Rainbow("Deploying to staging environment").yellow
    Rake::Task["pulumi:deploy"].invoke("staging")

    # Wait for confirmation before proceeding to production
    puts Rainbow("Staging deployment complete. Run tests on staging before proceeding.").cyan
    print Rainbow("Deploy to production? (yes/no): ").bright.yellow
    response = STDIN.gets.chomp.downcase

    if response == "yes"
      puts Rainbow("Starting blue/green deployment to production").yellow

      # Deploy to production with blue/green strategy
      puts Rainbow("Deploying new version (green) alongside existing version (blue)").cyan
      sh "pulumi stack select production"
      sh "pulumi config set deployment:strategy blue-green"
      sh "pulumi config set deployment:traffic_split 0"
      sh "pulumi up --yes"

      # Gradually shift traffic
      [ 25, 50, 75, 100 ].each do |percentage|
        puts Rainbow("Shifting #{percentage}% of traffic to new version").cyan
        sh "pulumi config set deployment:traffic_split #{percentage}"
        sh "pulumi up --yes"

        # Wait for monitoring before proceeding
        puts Rainbow("Monitoring new deployment for 30 seconds...").yellow
        sleep 30

        # Check if we should proceed
        unless percentage == 100
          print Rainbow("Continue with traffic shift? (yes/no): ").bright.yellow
          response = STDIN.gets.chomp.downcase
          break unless response == "yes"
        end
      end

      puts Rainbow("Deployment complete! 100% of traffic now on new version.").bright.green
    else
      puts Rainbow("Production deployment cancelled.").red
    end
  end

  desc "Destroy specified infrastructure (environment)"
  task :nuke, [ :environment ] do |t, args|
    environment = args[:environment] || "staging"

    puts Rainbow("⚠️  WARNING: This will DESTROY the '#{environment}' environment! ⚠️").bright.red
    puts Rainbow("All resources will be permanently deleted!").red
    print Rainbow("Type the environment name again to confirm: ").bright.yellow
    confirmation = STDIN.gets.chomp

    if confirmation == environment
      puts Rainbow("Destroying #{environment} environment...").yellow
      sh "pulumi stack select #{environment}"

      # First export the state as backup
      timestamp = Time.now.strftime("%Y%m%d-%H%M%S")
      backup_file = "pulumi-#{environment}-backup-#{timestamp}.json"
      puts Rainbow("Creating backup first: #{backup_file}").cyan
      sh "pulumi stack export --file #{backup_file}"

      # Now destroy
      puts Rainbow("Proceeding with destruction...").red
      sh "pulumi destroy --yes"

      puts Rainbow("Infrastructure in #{environment} has been destroyed.").green
      puts Rainbow("A backup of the state was saved to: #{backup_file}").cyan
    else
      puts Rainbow("Destruction cancelled. Confirmation did not match.").green
    end
  end
end
