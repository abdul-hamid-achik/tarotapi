desc "API key management tasks"
namespace :api_keys do
  desc "Generate a new API key for a user"
  task :generate, [ :email, :name, :description, :expires_in, :rate_limit ] => :environment do |_, args|
    email = args[:email]
    name = args[:name] || "CLI Generated Key"
    description = args[:description] || "API key generated via CLI"
    expires_in = args[:expires_in].present? ? args[:expires_in].to_i.days.from_now : nil
    rate_limit = args[:rate_limit] || 1000

    unless email.present?
      TaskLogger.error("Email is required")
      TaskLogger.info("Usage: rake api_keys:generate[user@example.com,MyKey,Description,30,1000]")
      TaskLogger.info("  - email: Required. User email")
      TaskLogger.info("  - name: Optional. Name for the key (default: CLI Generated Key)")
      TaskLogger.info("  - description: Optional. Description for the key")
      TaskLogger.info("  - expires_in: Optional. Days until expiration (nil for no expiry)")
      TaskLogger.info("  - rate_limit: Optional. Hourly rate limit (default: 1000)")
      exit 1
    end

    user = User.find_by(email: email)

    unless user
      TaskLogger.error("User with email #{email} not found")
      exit 1
    end

    unless user.registered?
      TaskLogger.error("Only registered users can have API keys")
      exit 1
    end

    api_key = user.api_keys.new(
      name: name,
      description: description,
      expires_at: expires_in,
      rate_limit: rate_limit
    )

    if api_key.save
      TaskLogger.info("API key generated successfully")
      TaskLogger.info("="*50)
      TaskLogger.info("Key details:")
      TaskLogger.info("  ID: #{api_key.id}")
      TaskLogger.info("  Name: #{api_key.name}")
      TaskLogger.info("  Description: #{api_key.description}")
      TaskLogger.info("  Token: #{api_key.token} 🔒 SAVE THIS - IT WON'T BE SHOWN AGAIN")
      TaskLogger.info("  Expires at: #{api_key.expires_at || 'Never'}")
      TaskLogger.info("  Rate limit: #{api_key.rate_limit} requests/hour")
      TaskLogger.info("  Created at: #{api_key.created_at}")
      TaskLogger.info("="*50)
      TaskLogger.info("Usage:")
      TaskLogger.info("  curl -H \"X-API-Key: #{api_key.token}\" https://yourdomain.com/api/v1/resource")
      TaskLogger.info("="*50)
    else
      TaskLogger.error("Error creating API key:")
      api_key.errors.full_messages.each do |message|
        TaskLogger.error("  - #{message}")
      end
      exit 1
    end
  end

  desc "List all API keys for a user by email"
  task :list, [ :email ] => :environment do |t, args|
    unless args[:email]
      TaskLogger.error("Email required. Usage: rake api_keys:list[user@example.com]")
      exit 1
    end

    user = User.find_by(email: args[:email])
    unless user
      TaskLogger.error("User not found with email #{args[:email]}")
      exit 1
    end

    keys = user.api_keys.order(created_at: :desc)
    if keys.empty?
      TaskLogger.info("No API keys found for #{user.email}")
    else
      TaskLogger.info("API Keys for #{user.email}:")
      keys.each do |key|
        status = key.usable? ? "ACTIVE" : "INACTIVE"
        expiry = key.expires_at ? key.expires_at.strftime("%Y-%m-%d") : "never"
        last_used = key.last_used_at ? key.last_used_at.strftime("%Y-%m-%d %H:%M:%S") : "never"
        TaskLogger.info("- #{key.name} (#{status})")
        TaskLogger.info("  Token: #{key.token}")
        TaskLogger.info("  Created: #{key.created_at.strftime("%Y-%m-%d")}")
        TaskLogger.info("  Expires: #{expiry}")
        TaskLogger.info("  Last used: #{last_used}")
        TaskLogger.info("")
      end
    end
  end

  desc "Create a new API key for a user by email"
  task :create, [ :email, :name, :expires_in_days ] => :environment do |t, args|
    unless args[:email] && args[:name]
      TaskLogger.error("Email and name required. Usage: rake api_keys:create[user@example.com,key_name,30]")
      exit 1
    end

    user = User.find_by(email: args[:email])
    unless user
      TaskLogger.error("User not found with email #{args[:email]}")
      exit 1
    end

    expires_at = args[:expires_in_days].present? ? args[:expires_in_days].to_i.days.from_now : nil

    key = user.api_keys.create!(
      name: args[:name],
      expires_at: expires_at,
      active: true
    )

    TaskLogger.info("API key created for #{user.email}:")
    TaskLogger.info("- Name: #{key.name}")
    TaskLogger.info("- Token: #{key.token}")
    TaskLogger.info("- Expires: #{expires_at ? expires_at.strftime("%Y-%m-%d") : "never"}")
  end

  desc "Revoke an API key by token"
  task :revoke, [ :token ] => :environment do |t, args|
    unless args[:token]
      TaskLogger.error("Token required. Usage: rake api_keys:revoke[token]")
      exit 1
    end

    key = ApiKey.find_by(token: args[:token])
    unless key
      TaskLogger.error("API key not found with token #{args[:token]}")
      exit 1
    end

    key.update!(active: false)
    TaskLogger.info("API key #{key.name} belonging to #{key.user.email} has been revoked.")
  end

  desc "Show API key usage statistics"
  task stats: :environment do
    total_keys = ApiKey.count
    active_keys = ApiKey.active.count
    expired_keys = ApiKey.where("expires_at < ?", Time.current).count
    revoked_keys = ApiKey.where(active: false).count
    unused_keys = ApiKey.where(last_used_at: nil).count
    used_last_24h = ApiKey.where("last_used_at > ?", 24.hours.ago).count

    TaskLogger.info("API Key Statistics:")
    TaskLogger.info("="*50)
    TaskLogger.info("Total API keys: #{total_keys}")
    TaskLogger.info("Active keys: #{active_keys}")
    TaskLogger.info("Expired keys: #{expired_keys}")
    TaskLogger.info("Revoked keys: #{revoked_keys}")
    TaskLogger.info("Unused keys: #{unused_keys}")
    TaskLogger.info("Keys used in last 24h: #{used_last_24h}")
    TaskLogger.info("="*50)

    # Most active keys
    TaskLogger.info("\nMost active keys (by recent usage):")
    TaskLogger.info("-"*80)
    TaskLogger.info("%-5s | %-20s | %-20s | %-20s | %-10s" % [
      "ID", "Name", "User", "Last Used", "Created"
    ])
    TaskLogger.info("-"*80)

    ApiKey.where.not(last_used_at: nil)
          .order(last_used_at: :desc)
          .includes(:user)
          .limit(10)
          .each do |key|
      TaskLogger.info("%-5s | %-20s | %-20s | %-20s | %-10s" % [
        key.id,
        key.name.to_s.truncate(20),
        key.user.email.to_s.truncate(20),
        key.last_used_at.strftime("%Y-%m-%d %H:%M"),
        key.created_at.strftime("%Y-%m-%d")
      ])
    end
    TaskLogger.info("="*80)
  end
end
