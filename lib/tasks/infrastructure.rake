# this file is kept for backward compatibility
# most functionality has been moved to deploy.rake

namespace :infrastructure do
  desc "setup pulumi environment (redirects to pulumi:setup)"
  task :setup do
    Rake::Task["pulumi:setup"].invoke
  end

  desc "preview infrastructure changes (redirects to deploy:validate)"
  task :preview do
    Rake::Task["deploy:validate"].invoke
  end

  desc "apply infrastructure changes (redirects to deploy:infrastructure)"
  task :apply do
    Rake::Task["deploy:infrastructure"].invoke
  end

  desc "destroy infrastructure (redirects to deploy:destroy)"
  task :destroy do
    Rake::Task["deploy:destroy"].invoke
  end

  desc "get infrastructure outputs (redirects to pulumi:outputs)"
  task :outputs do
    Rake::Task["pulumi:outputs"].invoke
  end

  desc "refresh infrastructure state (redirects to pulumi:refresh)"
  task :refresh do
    Rake::Task["pulumi:refresh"].invoke
  end

  desc "initialize a new stack"
  task :init, [:stack_name] do |_, args|
    stack_name = args[:stack_name] || "dev"
    puts "initializing #{stack_name} stack..."
    system("cd infrastructure && pulumi stack init #{stack_name}") || exit(1)
  end

  desc "configure aws credentials and region"
  task :configure do
    puts "configuring aws credentials..."
    region = ENV.fetch("aws_region", "us-west-2")
    system("cd infrastructure && pulumi config set aws:region #{region}") || exit(1)
    
    # set required configuration values
    system("cd infrastructure && pulumi config set domain_name #{ENV['domain_name']}") || exit(1)
    system("cd infrastructure && pulumi config set hosted_zone_id #{ENV['hosted_zone_id']}") || exit(1)
  end

  namespace :secrets do
    desc "create or update aws secrets"
    task :sync do
      require "aws-sdk-ssm"
      ssm = Aws::SSM::Client.new(region: ENV.fetch("aws_region", "us-west-2"))
      
      # sync database credentials
      ssm.put_parameter({
        name: "/#{Rails.env}/database_url",
        value: "postgres://#{ENV['db_username']}:#{ENV['db_password']}@#{ENV['db_host']}/#{ENV['db_name']}",
        type: "SecureString",
        overwrite: true
      })

      # sync redis url
      ssm.put_parameter({
        name: "/#{Rails.env}/redis_url",
        value: ENV['redis_url'],
        type: "SecureString",
        overwrite: true
      })

      # sync rails master key
      ssm.put_parameter({
        name: "/#{Rails.env}/rails_master_key",
        value: ENV['rails_master_key'],
        type: "SecureString",
        overwrite: true
      })

      puts "secrets synced successfully"
    end
  end
end 