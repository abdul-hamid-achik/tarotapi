namespace :usage do
  desc "initialize usage tracking system"
  task setup: :environment do
    puts "setting up usage tracking system..."
    
    unless ActiveRecord::Base.connection.table_exists?("reading_quotas")
      puts "creating reading_quotas table..."
      ActiveRecord::Base.connection.create_table :reading_quotas do |t|
        t.references :user, null: false, foreign_key: true
        t.integer :monthly_limit, default: 100
        t.integer :readings_this_month, default: 0
        t.datetime :reset_date
        t.timestamps
      end
    end
    
    puts "✅ usage tracking tables initialized"
  end
  
  desc "reset monthly counters for users who have reached their reset date"
  task reset_counters: :environment do
    puts "resetting monthly counters for eligible users..."
    
    if ActiveRecord::Base.connection.table_exists?("reading_quotas")
      sql = <<-SQL
        UPDATE reading_quotas 
        SET readings_this_month = 0, 
            reset_date = DATE_TRUNC('month', NOW()) + INTERVAL '1 month'
        WHERE reset_date <= NOW()
      SQL
      
      count = ActiveRecord::Base.connection.execute(sql).cmd_tuples
      puts "✅ reset #{count} user quotas"
    else
      puts "❌ reading_quotas table doesn't exist"
    end
  end
  
  desc "set quota for a specific user"
  task :set_quota, [:email, :limit] => :environment do |_, args|
    email = args[:email] || abort("email required")
    limit = args[:limit]&.to_i || abort("limit required")
    
    user = User.find_by(email: email)
    abort "user not found" unless user
    
    puts "setting quota for user #{email} to #{limit} readings per month..."
    
    if ActiveRecord::Base.connection.table_exists?("reading_quotas")
      quota = ReadingQuota.find_or_initialize_by(user_id: user.id)
      quota.update!(
        monthly_limit: limit,
        reset_date: quota.reset_date || Date.today.end_of_month + 1.day
      )
      puts "✅ quota updated: #{limit} readings per month"
    else
      puts "❌ reading_quotas table doesn't exist"
    end
  end
  
  desc "update all free user quotas to a new limit"
  task :update_free_tier, [:limit] => :environment do |_, args|
    limit = args[:limit]&.to_i || abort("limit required")
    
    puts "updating all free tier users to #{limit} readings per month..."
    
    if ActiveRecord::Base.connection.table_exists?("reading_quotas")
      # Only update users without active subscriptions
      free_users = User.where(subscription_status: [nil, "inactive"])
      count = 0
      
      free_users.find_each do |user|
        quota = ReadingQuota.find_or_initialize_by(user_id: user.id)
        quota.update!(
          monthly_limit: limit,
          reset_date: quota.reset_date || Date.today.end_of_month + 1.day
        )
        count += 1
      end
      
      puts "✅ updated #{count} free user quotas to #{limit} readings per month"
    else
      puts "❌ reading_quotas table doesn't exist"
    end
  end
  
  desc "check remaining quotas for all users"
  task check_quotas: :environment do
    puts "checking reading quotas for all users..."
    
    if ActiveRecord::Base.connection.table_exists?("reading_quotas")
      ReadingQuota.includes(:user).find_each do |quota|
        remaining = quota.monthly_limit - quota.readings_this_month
        status = remaining <= 0 ? "❌ EXCEEDED" : 
                 remaining < 5 ? "⚠️ LOW" : "✅ OK"
                 
        puts "#{status} | #{quota.user.email}: #{remaining}/#{quota.monthly_limit} readings remaining (resets: #{quota.reset_date&.strftime('%Y-%m-%d')})"
      end
    else
      puts "❌ reading_quotas table doesn't exist"
    end
  end
  
  desc "increment usage for a user"
  task :increment, [:email] => :environment do |_, args|
    email = args[:email] || abort("email required")
    
    user = User.find_by(email: email)
    abort "user not found" unless user
    
    puts "incrementing usage counter for #{email}..."
    
    if ActiveRecord::Base.connection.table_exists?("reading_quotas")
      quota = ReadingQuota.find_or_initialize_by(user_id: user.id)
      
      if !quota.reset_date
        quota.reset_date = Date.today.end_of_month + 1.day
      end
      
      if user.subscription_status == "active"
        puts "ℹ️ user has active subscription - not counting against quota"
      else
        old_count = quota.readings_this_month
        quota.readings_this_month += 1
        quota.save!
        
        remaining = quota.monthly_limit - quota.readings_this_month
        puts "✅ usage incremented: #{old_count} → #{quota.readings_this_month} (#{remaining} remaining this month)"
        
        if remaining <= 0
          puts "⚠️ user has exceeded their monthly quota"
        elsif remaining < 5
          puts "ℹ️ user is approaching their monthly quota"
        end
      end
    else
      puts "❌ reading_quotas table doesn't exist"
    end
  end
  
  desc "setup usage tracking and run initial quota configurations"
  task init: :environment do
    puts "initializing usage tracking system..."
    
    Rake::Task["usage:setup"].invoke
    
    # Set default quota for free tier (100 readings per month)
    ENV["DEFAULT_FREE_TIER_LIMIT"] ||= "100"
    free_limit = ENV["DEFAULT_FREE_TIER_LIMIT"].to_i
    
    puts "setting default free tier limit to #{free_limit} readings per month..."
    Rake::Task["usage:update_free_tier"].invoke(free_limit)
    
    puts "✅ usage tracking initialization complete"
  end
end 