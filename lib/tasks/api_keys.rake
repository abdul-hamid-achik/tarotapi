desc "API key management tasks"
namespace :api_keys do
  desc "Generate a new API key for a user"
  task :generate, [:email, :name, :description, :expires_in, :rate_limit] => :environment do |_, args|
    email = args[:email]
    name = args[:name] || "CLI Generated Key"
    description = args[:description] || "API key generated via CLI"
    expires_in = args[:expires_in].present? ? args[:expires_in].to_i.days.from_now : nil
    rate_limit = args[:rate_limit] || 1000

    unless email.present?
      puts "❌ Error: Email is required"
      puts "Usage: rake api_keys:generate[user@example.com,MyKey,Description,30,1000]"
      puts "  - email: Required. User email"
      puts "  - name: Optional. Name for the key (default: CLI Generated Key)"
      puts "  - description: Optional. Description for the key"
      puts "  - expires_in: Optional. Days until expiration (nil for no expiry)"
      puts "  - rate_limit: Optional. Hourly rate limit (default: 1000)"
      exit 1
    end

    user = User.find_by(email: email)

    unless user
      puts "❌ Error: User with email #{email} not found"
      exit 1
    end

    unless user.registered?
      puts "❌ Error: Only registered users can have API keys"
      exit 1
    end

    api_key = user.api_keys.new(
      name: name,
      description: description,
      expires_at: expires_in,
      rate_limit: rate_limit
    )

    if api_key.save
      puts "✅ API key generated successfully"
      puts "="*50
      puts "Key details:"
      puts "  ID: #{api_key.id}"
      puts "  Name: #{api_key.name}"
      puts "  Description: #{api_key.description}"
      puts "  Token: #{api_key.token} 🔒 SAVE THIS - IT WON'T BE SHOWN AGAIN"
      puts "  Expires at: #{api_key.expires_at || 'Never'}"
      puts "  Rate limit: #{api_key.rate_limit} requests/hour"
      puts "  Created at: #{api_key.created_at}"
      puts "="*50
      puts "Usage:"
      puts "  curl -H \"X-API-Key: #{api_key.token}\" https://yourdomain.com/api/v1/resource"
      puts "="*50
    else
      puts "❌ Error creating API key:"
      api_key.errors.full_messages.each do |message|
        puts "  - #{message}"
      end
      exit 1
    end
  end

  desc "List all API keys for a user by email"
  task :list, [:email] => :environment do |t, args|
    unless args[:email]
      puts "Error: Email required. Usage: rake api_keys:list[user@example.com]"
      exit 1
    end
    
    user = User.find_by(email: args[:email])
    unless user
      puts "Error: User not found with email #{args[:email]}"
      exit 1
    end
    
    keys = user.api_keys.order(created_at: :desc)
    if keys.empty?
      puts "No API keys found for #{user.email}"
    else
      puts "API Keys for #{user.email}:"
      keys.each do |key|
        status = key.usable? ? "ACTIVE" : "INACTIVE"
        expiry = key.expires_at ? key.expires_at.strftime("%Y-%m-%d") : "never"
        last_used = key.last_used_at ? key.last_used_at.strftime("%Y-%m-%d %H:%M:%S") : "never"
        puts "- #{key.name} (#{status})"
        puts "  Token: #{key.token}"
        puts "  Created: #{key.created_at.strftime("%Y-%m-%d")}"
        puts "  Expires: #{expiry}"
        puts "  Last used: #{last_used}"
        puts ""
      end
    end
  end
  
  desc "Create a new API key for a user by email"
  task :create, [:email, :name, :expires_in_days] => :environment do |t, args|
    unless args[:email] && args[:name]
      puts "Error: Email and name required. Usage: rake api_keys:create[user@example.com,key_name,30]"
      exit 1
    end
    
    user = User.find_by(email: args[:email])
    unless user
      puts "Error: User not found with email #{args[:email]}"
      exit 1
    end
    
    expires_at = args[:expires_in_days].present? ? args[:expires_in_days].to_i.days.from_now : nil
    
    key = user.api_keys.create!(
      name: args[:name],
      expires_at: expires_at,
      active: true
    )
    
    puts "API key created for #{user.email}:"
    puts "- Name: #{key.name}"
    puts "- Token: #{key.token}"
    puts "- Expires: #{expires_at ? expires_at.strftime("%Y-%m-%d") : "never"}"
  end
  
  desc "Revoke an API key by token"
  task :revoke, [:token] => :environment do |t, args|
    unless args[:token]
      puts "Error: Token required. Usage: rake api_keys:revoke[token]"
      exit 1
    end
    
    key = ApiKey.find_by(token: args[:token])
    unless key
      puts "Error: API key not found with token #{args[:token]}"
      exit 1
    end
    
    key.update!(active: false)
    puts "API key #{key.name} belonging to #{key.user.email} has been revoked."
  end

  desc "Show API key usage statistics"
  task :stats => :environment do
    total_keys = ApiKey.count
    active_keys = ApiKey.active.count
    expired_keys = ApiKey.where("expires_at < ?", Time.current).count
    revoked_keys = ApiKey.where(active: false).count
    unused_keys = ApiKey.where(last_used_at: nil).count
    used_last_24h = ApiKey.where("last_used_at > ?", 24.hours.ago).count

    puts "API Key Statistics:"
    puts "="*50
    puts "Total API keys: #{total_keys}"
    puts "Active keys: #{active_keys}"
    puts "Expired keys: #{expired_keys}"
    puts "Revoked keys: #{revoked_keys}"
    puts "Unused keys: #{unused_keys}"
    puts "Keys used in last 24h: #{used_last_24h}"
    puts "="*50

    # Most active keys
    puts "\nMost active keys (by recent usage):"
    puts "-"*80
    puts "%-5s | %-20s | %-20s | %-20s | %-10s" % [
      "ID", "Name", "User", "Last Used", "Created"
    ]
    puts "-"*80

    ApiKey.where.not(last_used_at: nil)
          .order(last_used_at: :desc)
          .includes(:user)
          .limit(10)
          .each do |key|
      puts "%-5s | %-20s | %-20s | %-20s | %-10s" % [
        key.id,
        key.name.to_s.truncate(20),
        key.user.email.to_s.truncate(20),
        key.last_used_at.strftime("%Y-%m-%d %H:%M"),
        key.created_at.strftime("%Y-%m-%d")
      ]
    end
    puts "="*80
  end
end 