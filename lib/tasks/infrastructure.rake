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
        passphrase = ENV["PULUMI_CONFIG_PASSPHRASE"]
        TaskLogger.info "Passphrase present: #{!passphrase.nil?}"
        TaskLogger.info "Passphrase length: #{passphrase&.length}"

        TaskLogger.info "Creating staging stack..."
        system("PULUMI_CONFIG_PASSPHRASE='#{passphrase}' pulumi stack init staging --secrets-provider passphrase")

        TaskLogger.info "Creating production stack..."
        system("PULUMI_CONFIG_PASSPHRASE='#{passphrase}' pulumi stack init production --secrets-provider passphrase")

        TaskLogger.info "Configuring AWS region..."
        system("PULUMI_CONFIG_PASSPHRASE='#{passphrase}' pulumi config set aws:region mx-central-1 --stack staging")
        system("PULUMI_CONFIG_PASSPHRASE='#{passphrase}' pulumi config set aws:region mx-central-1 --stack production")
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
        system("pulumi stack init preview-#{name} --secrets-provider passphrase")
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
        system("pulumi stack select #{env}")
        
        # Run Pulumi up with JSON output and format it
        output = `pulumi up --yes --json`
        begin
          require 'json'
          result = JSON.parse(output)
          # Extract summary information
          summary = result["summary"] || {}
          
          TaskLogger.info "----- Infrastructure Deployment Summary -----"
          TaskLogger.info "Resources:"
          TaskLogger.info "  Created: #{summary["create"] || 0}"
          TaskLogger.info "  Updated: #{summary["update"] || 0}"
          TaskLogger.info "  Deleted: #{summary["delete"] || 0}"
          TaskLogger.info "  Unchanged: #{summary["same"] || 0}"
          
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
          require 'json'
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
end
