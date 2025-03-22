namespace :infra do
  desc 'Initialize infrastructure stack'
  task :init do
    require 'dotenv'
    require 'semantic_logger'
    require_relative '../task_logger'
    
    # Configure semantic logger
    SemanticLogger.default_level = :info
    SemanticLogger.add_appender(io: $stdout, formatter: :color)
    
    Dotenv.load
    
    TaskLogger.with_task_logging('infra:init') do
      Dir.chdir(File.expand_path('../../infrastructure', __dir__)) do
        passphrase = ENV['PULUMI_CONFIG_PASSPHRASE']
        TaskLogger.info "Passphrase present: #{!passphrase.nil?}"
        TaskLogger.info "Passphrase length: #{passphrase&.length}"  
        
        TaskLogger.info 'Creating staging stack...'
        system("PULUMI_CONFIG_PASSPHRASE='#{passphrase}' pulumi stack init staging --secrets-provider passphrase")
        
        TaskLogger.info 'Creating production stack...'
        system("PULUMI_CONFIG_PASSPHRASE='#{passphrase}' pulumi stack init production --secrets-provider passphrase")
        
        TaskLogger.info 'Configuring AWS region...'
        system("PULUMI_CONFIG_PASSPHRASE='#{passphrase}' pulumi config set aws:region mx-central-1 --stack staging")
        system("PULUMI_CONFIG_PASSPHRASE='#{passphrase}' pulumi config set aws:region mx-central-1 --stack production")
      end
    end
  end

  desc 'Deploy infrastructure to staging'
  task :deploy_staging => :environment do
    TaskLogger.with_task_logging('infra:deploy_staging') do
      Dir.chdir(Rails.root.join('infrastructure')) do
        system('pulumi stack select staging')
        system('pulumi up --yes')
      end
    end
  end

  desc 'Deploy infrastructure to production'
  task :deploy_prod => :environment do
    TaskLogger.with_task_logging('infra:deploy_prod') do
      Dir.chdir(Rails.root.join('infrastructure')) do
        system('pulumi stack select production')
        system('pulumi up --yes')
      end
    end
  end

  desc 'Show infrastructure outputs'
  task :outputs => :environment do
    TaskLogger.with_task_logging('infra:outputs') do
      Dir.chdir(Rails.root.join('infrastructure')) do
        system('pulumi stack output --json')
      end
    end
  end

  desc 'Destroy infrastructure (use with caution!)'
  task :destroy => :environment do
    TaskLogger.with_task_logging('infra:destroy') do
      TaskLogger.warn('WARNING: This will destroy all infrastructure!')
      print 'Are you sure? (y/n): '
      confirm = STDIN.gets.chomp
      if confirm.downcase == 'y'
        Dir.chdir(Rails.root.join('infrastructure')) do
          system('pulumi destroy --yes')
        end
      end
    end
  end
end 