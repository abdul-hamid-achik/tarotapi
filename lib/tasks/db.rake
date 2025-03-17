namespace :db do
  desc "Checks if the database exists"
  task exists: :environment do
    begin
      # Check if the database exists
      ActiveRecord::Base.connection
      puts "true"
      exit 0
    rescue ActiveRecord::NoDatabaseError
      puts "false"
      exit 1
    end
  end
end 