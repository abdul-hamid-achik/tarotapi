namespace :pulumi do
  desc "setup pulumi environment"
  task setup: :load_env do
    puts "setting up pulumi environment..."
    system("cd infrastructure && pulumi login") || exit(1)
  end

  desc "get infrastructure outputs"
  task outputs: :load_env do
    puts "fetching infrastructure outputs..."
    system("cd infrastructure && pulumi stack output --json") || exit(1)
  end

  desc "refresh infrastructure state"
  task refresh: :load_env do
    puts "refreshing infrastructure state..."
    system("cd infrastructure && pulumi refresh --yes") || exit(1)
  end

  desc "generate a new pulumi encryption salt"
  task :generate_salt do
    require 'securerandom'
    salt = SecureRandom.hex(32) # 64 characters hex string
    puts "\ngenerated new pulumi encryption salt:"
    puts "\nexport PULUMI_ENCRYPTION_SALT=#{salt}"
    puts "\nadd this to your .env file:"
    puts "PULUMI_ENCRYPTION_SALT=#{salt}"
  end
end 