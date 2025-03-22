# This initializer ensures the database configuration matches the current Rails environment
# This fixes issues where test tasks were affecting the development database

Rails.application.config.after_initialize do
  if ActiveRecord::Base.connection_db_config.configuration_hash[:database] != "tarot_api_#{Rails.env}"
    puts "⚠️ WARNING: Database name mismatch detected!"
    puts "  Current environment: #{Rails.env}"
    puts "  Database being used: #{ActiveRecord::Base.connection_db_config.configuration_hash[:database]}"
    puts "  Expected database: tarot_api_#{Rails.env}"
    puts ""
    puts "This could cause unexpected behavior. Please ensure your database.yml"
    puts "has the correct configuration for each environment."
    
    # Only forcibly abort in test environment
    if Rails.env.test? && ENV['FORCE_DB'] != 'true' 
      abort "ERROR: Database incorrect for test environment. Aborting to prevent data loss."
    end
  end
end 