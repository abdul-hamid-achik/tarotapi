require "dotenv"
require "semantic_logger"
require_relative "../task_logger"

namespace :infra do
  desc "Initialize infrastructure stack"
  task :init do
    # Configure semantic logger
    SemanticLogger.default_level = :info
    SemanticLogger.add_appender(io: $stdout, formatter: :color)

    Dotenv.load

    TaskLogger.with_task_logging("infra:init") do
      Dir.chdir(File.expand_path("../../infrastructure", __dir__)) do
        # Remove passphrase references since we're using Pulumi service
        TaskLogger.info "Using Pulumi service for secrets management"

        # Add check if stacks already exist to avoid errors
        staging_exists = system("pulumi stack select staging 2>/dev/null")
        production_exists = system("pulumi stack select production 2>/dev/null")

        # Only create staging stack if it doesn't exist
        unless staging_exists
          TaskLogger.info "Creating staging stack..."
          result = system("pulumi stack init staging --non-interactive")

          if result
            TaskLogger.info "Staging stack created successfully"
          else
            TaskLogger.warn "Failed to create staging stack, it may already exist"
          end
        else
          TaskLogger.info "Staging stack already exists, skipping creation"
        end

        # Only create production stack if it doesn't exist
        unless production_exists
          TaskLogger.info "Creating production stack..."
          result = system("pulumi stack init production --non-interactive")

          if result
            TaskLogger.info "Production stack created successfully"
          else
            TaskLogger.warn "Failed to create production stack, it may already exist"
          end
        else
          TaskLogger.info "Production stack already exists, skipping creation"
        end

        TaskLogger.info "Configuring AWS region..."
        system("pulumi config set aws:region mx-central-1 --stack staging")
        system("pulumi config set aws:region mx-central-1 --stack production")
      end
    end
  end

  desc "Create preview environment"
  task :create_preview, [ :name ] do |t, args|
    name = args[:name] || raise("Preview name required")
    require "semantic_logger"
    require_relative "../task_logger"

    # Configure semantic logger
    SemanticLogger.default_level = :info
    SemanticLogger.add_appender(io: $stdout, formatter: :color)

    TaskLogger.with_task_logging("infra:create_preview:#{name}") do
      Dir.chdir(File.expand_path("../../infrastructure", __dir__)) do
        TaskLogger.info "Creating preview environment: #{name}..."

        # Check if preview stack already exists
        preview_exists = system("pulumi stack select preview-#{name} 2>/dev/null")

        unless preview_exists
          TaskLogger.info "Creating preview stack..."
          result = system("pulumi stack init preview-#{name} --non-interactive")

          if result
            TaskLogger.info "Preview stack created successfully"
          else
            TaskLogger.warn "Failed to create preview stack, it may already exist"
          end
        else
          TaskLogger.info "Preview stack already exists, skipping creation"
        end

        system("pulumi config set aws:region mx-central-1 --stack preview-#{name}")
        system("pulumi up --yes --stack preview-#{name}")
      end
    end
  end

  desc "Deploy infrastructure to specified environment"
  task :deploy, [ :env ] do |t, args|
    env = args[:env] || "staging"
    require "semantic_logger"
    require_relative "../task_logger"

    # Configure semantic logger
    SemanticLogger.default_level = :info
    SemanticLogger.add_appender(io: $stdout, formatter: :color)

    TaskLogger.with_task_logging("infra:deploy:#{env}") do
      Dir.chdir(File.expand_path("../../infrastructure", __dir__)) do
        TaskLogger.info "Deploying infrastructure to #{env}..."

        # Check if the stack exists first
        TaskLogger.info "Selecting stack #{env}..."
        system("pulumi stack select #{env}")

        # Run Pulumi preview to see what changes would be made (and debug issues)
        TaskLogger.info "Running Pulumi preview to diagnose configuration..."
        preview_output = `pulumi preview --json`

        begin
          require "json"
          preview_result = JSON.parse(preview_output)

          if preview_result["diagnostics"] && !preview_result["diagnostics"].empty?
            # Display diagnostic information to help debug Pulumi issues
            TaskLogger.warn "----- Pulumi Configuration Diagnostics -----"
            preview_result["diagnostics"].each do |diagnostic|
              TaskLogger.warn "#{diagnostic['severity']}: #{diagnostic['message']}"
            end
            TaskLogger.warn "--------------------------------------------"
          end

          # Check if any resources would be created
          if preview_result["changeSummary"] && preview_result["changeSummary"]["create"] == 0
            TaskLogger.warn "No resources would be created. This may indicate missing configuration."
            TaskLogger.warn "Check that you have set the required environment variables for Pulumi."
            TaskLogger.warn "Required variables might include: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, etc."
          end

        rescue => e
          TaskLogger.warn "Could not parse Pulumi preview output: #{e.message}"
          TaskLogger.info preview_output
        end

        # Check environment variables that might be required for the Pulumi deployment
        TaskLogger.info "Checking required environment variables..."
        required_vars = [ "AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY", "AWS_DEFAULT_REGION",
                          "PULUMI_CONFIG_PASSPHRASE", "PULUMI_ACCESS_TOKEN" ]

        missing_vars = required_vars.select { |var| ENV[var].nil? || ENV[var].empty? }
        if missing_vars.any?
          TaskLogger.warn "Missing required environment variables: #{missing_vars.join(', ')}"
        end

        # Try to ensure the stack has minimal configuration
        ensure_basic_config(env)

        # Run the actual deployment
        TaskLogger.info "Running Pulumi deployment to #{env}..."
        output = `pulumi up --yes --json`

        begin
          require "json"
          result = JSON.parse(output)
          # Extract summary information
          summary = result["summary"] || {}

          TaskLogger.info "----- Infrastructure Deployment Summary -----"
          TaskLogger.info "Resources:"
          TaskLogger.info "  Created: #{summary["create"] || 0}"
          TaskLogger.info "  Updated: #{summary["update"] || 0}"
          TaskLogger.info "  Deleted: #{summary["delete"] || 0}"
          TaskLogger.info "  Unchanged: #{summary["same"] || 0}"

          # If no resources were created or changed, explain possible issues
          if (summary["create"] || 0) == 0 && (summary["update"] || 0) == 0
            TaskLogger.warn "No resources were created or updated. This may indicate:"
            TaskLogger.warn "1. Resources already exist and are up-to-date"
            TaskLogger.warn "2. Required configuration is missing"
            TaskLogger.warn "3. There might be errors in the Pulumi configuration"

            # Check if stack has been properly initialized
            stack_output = `pulumi stack output --json --stack #{env} 2>/dev/null`.strip
            if stack_output == "{}" || stack_output.empty?
              TaskLogger.warn "The stack appears to be empty. Try running:"
              TaskLogger.warn "1. cd infrastructure"
              TaskLogger.warn "2. pulumi stack init #{env} --secrets-provider passphrase"
              TaskLogger.warn "3. pulumi config set aws:region mx-central-1"
              TaskLogger.warn "4. Set any required config values with: pulumi config set <key> <value>"
              TaskLogger.warn "5. Then run: pulumi up --yes"
            end
          end

          # Display outputs separately for clarity
          if result["outputs"] && !result["outputs"].empty?
            TaskLogger.info "\nOutputs:"
            result["outputs"].each do |key, output_data|
              if output_data["value"].is_a?(String)
                TaskLogger.info "  #{key}: #{output_data["value"]}"
              else
                TaskLogger.info "  #{key}: #{output_data["value"].inspect}"
              end
            end
          end
          TaskLogger.info "-------------------------------------------"
        rescue => e
          # If JSON parsing fails, just output the raw result
          TaskLogger.info output
        end
      end
    end
  end

  desc "Destroy infrastructure in specified environment"
  task :destroy, [ :env ] do |t, args|
    env = args[:env] || raise("Environment required")
    require "semantic_logger"
    require_relative "../task_logger"

    # Configure semantic logger
    SemanticLogger.default_level = :info
    SemanticLogger.add_appender(io: $stdout, formatter: :color)

    TaskLogger.with_task_logging("infra:destroy:#{env}") do
      Dir.chdir(File.expand_path("../../infrastructure", __dir__)) do
        TaskLogger.warn "WARNING: This will destroy all infrastructure in #{env}!"
        print "Are you sure? (y/n): "
        confirm = STDIN.gets.chomp
        if confirm.downcase == "y"
          TaskLogger.info "Destroying infrastructure in #{env}..."
          system("pulumi stack select #{env}")
          system("pulumi destroy --yes")
        end
      end
    end
  end

  desc "Manage Pulumi state (backup/restore)"
  task :manage_state, [ :action, :file ] do |t, args|
    action = args[:action] || raise("Action (backup/restore) required")
    require "semantic_logger"
    require_relative "../task_logger"

    # Configure semantic logger
    SemanticLogger.default_level = :info
    SemanticLogger.add_appender(io: $stdout, formatter: :color)

    TaskLogger.with_task_logging("infra:manage_state:#{action}") do
      Dir.chdir(File.expand_path("../../infrastructure", __dir__)) do
        case action
        when "backup"
          timestamp = Time.now.strftime("%Y%m%d_%H%M%S")
          backup_file = "pulumi_state_#{timestamp}.tar.gz"
          TaskLogger.info "Backing up Pulumi state to #{backup_file}..."
          system("pulumi stack export --all > #{backup_file}")
        when "restore"
          file = args[:file] || raise("Backup file required for restore")
          TaskLogger.info "Restoring Pulumi state from #{file}..."
          system("pulumi stack import --file #{file}")
        else
          raise "Invalid action: #{action}. Use 'backup' or 'restore'."
        end
      end
    end
  end

  desc "Show infrastructure outputs"
  task outputs: :environment do
    TaskLogger.with_task_logging("infra:outputs") do
      Dir.chdir(Rails.root.join("infrastructure")) do
        output = `pulumi stack output --json`
        begin
          require "json"
          result = JSON.parse(output)

          TaskLogger.info "----- Pulumi Stack Outputs -----"
          result.each do |key, value_data|
            if value_data.is_a?(Hash) && value_data["value"]
              TaskLogger.info "  #{key}: #{value_data["value"].inspect}"
            else
              TaskLogger.info "  #{key}: #{value_data.inspect}"
            end
          end
          TaskLogger.info "-------------------------------"
        rescue => e
          # If JSON parsing fails, just output the raw result
          TaskLogger.info output
        end
      end
    end
  end

  desc "Diagnose infrastructure issues"
  task :diagnose, [ :env ] do |t, args|
    env = args[:env] || "production"
    require "semantic_logger"
    require_relative "../task_logger"

    # Configure semantic logger
    SemanticLogger.default_level = :info
    SemanticLogger.add_appender(io: $stdout, formatter: :color)

    TaskLogger.with_task_logging("infra:diagnose:#{env}") do
      Dir.chdir(File.expand_path("../../infrastructure", __dir__)) do
        TaskLogger.info "Running diagnostics for Pulumi stack #{env}..."

        # Check if we can select the stack
        select_result = system("pulumi stack select #{env} 2>/dev/null")
        if !select_result
          TaskLogger.error "Could not select stack #{env}. The stack may not exist."
          TaskLogger.info "Creating stack #{env}..."
          system("pulumi stack init #{env} --secrets-provider passphrase")
        else
          TaskLogger.info "Successfully selected stack #{env}"
        end

        # Check config
        TaskLogger.info "Checking Pulumi configuration for stack #{env}..."
        config = `pulumi config 2>/dev/null`
        if config.empty?
          TaskLogger.warn "No configuration found for stack #{env}"
        else
          TaskLogger.info "Stack configuration:"
          TaskLogger.info config
        end

        # Check if Pulumi.#{env}.yaml exists
        stack_config_file = File.join(File.expand_path("../../infrastructure", __dir__), "Pulumi.#{env}.yaml")
        if File.exist?(stack_config_file)
          TaskLogger.info "Stack config file exists: #{stack_config_file}"
          # Show contents
          stack_config = File.read(stack_config_file)
          TaskLogger.info "Stack config contents:"
          TaskLogger.info stack_config
        else
          TaskLogger.warn "Stack config file does not exist: #{stack_config_file}"
        end

        # Run pulumi preview and check for issues
        TaskLogger.info "Running Pulumi preview to identify potential issues..."
        preview_output = `pulumi preview`
        TaskLogger.info "Preview output:"
        TaskLogger.info preview_output

        # Print required environment variables for Pulumi
        TaskLogger.info "Required environment variables for Pulumi:"
        required_vars = [ "AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY", "AWS_DEFAULT_REGION",
                         "PULUMI_CONFIG_PASSPHRASE", "PULUMI_ACCESS_TOKEN" ]

        required_vars.each do |var|
          if ENV[var].nil? || ENV[var].empty?
            TaskLogger.warn "#{var}: NOT SET"
          else
            TaskLogger.info "#{var}: SET (value hidden)"
          end
        end

        # Print debug information about the Pulumi.yaml main file
        pulumi_yaml = File.join(File.expand_path("../../infrastructure", __dir__), "Pulumi.yaml")
        if File.exist?(pulumi_yaml)
          TaskLogger.info "Pulumi.yaml exists and contains #{File.read(pulumi_yaml).lines.count} lines"
          # Get first few lines to check structure
          first_lines = File.read(pulumi_yaml).lines[0..10].join
          TaskLogger.info "Pulumi.yaml starts with:"
          TaskLogger.info first_lines
        else
          TaskLogger.error "Main Pulumi.yaml file not found!"
        end

        # Suggest next steps
        TaskLogger.info "\nSuggested next steps:"
        TaskLogger.info "1. Ensure all required environment variables are set"
        TaskLogger.info "2. Check that Pulumi.yaml contains valid resource definitions"
        TaskLogger.info "3. Verify AWS credentials have sufficient permissions"
        TaskLogger.info "4. Run 'pulumi refresh' to sync the stack with actual cloud state"
        TaskLogger.info "5. Try running 'rake infra:deploy[#{env}]' after fixing any issues"
      end
    end
  end

  private

  # Ensure the stack has a basic configuration so deployment can proceed
  def ensure_basic_config(env)
    # Check if AWS region is set
    region_output = `pulumi config get aws:region --stack #{env} 2>/dev/null`.strip
    if region_output.empty?
      TaskLogger.info "Setting AWS region to mx-central-1 for stack #{env}..."
      system("pulumi config set aws:region mx-central-1 --stack #{env}")
    end

    # Ensure project-specific configs are set
    # This will depend on what your project requires
    # Example:
    # domain_output = `pulumi config get domain --stack #{env} 2>/dev/null`.strip
    # if domain_output.empty?
    #   TaskLogger.info "Setting domain to tarotapi.cards for stack #{env}..."
    #   system("pulumi config set domain tarotapi.cards --stack #{env}")
    # end
  end
end
