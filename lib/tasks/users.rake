namespace :users do
  desc "create a new user"
  task :create, [ :email, :password ] => :environment do |_, args|
    email = args[:email] || abort("email required")
    password = args[:password] || abort("password required")

    puts "creating user #{email}..."

    begin
      user = User.create!(
        email: email,
        password: password,
        password_confirmation: password,
        identity_provider: IdentityProvider.registered
      )
      puts "user created successfully with id: #{user.id}"
    rescue => e
      abort "failed to create user: #{e.message}"
    end
  end

  desc "generate a token for a user"
  task :generate_token, [ :email, :password ] => :environment do |_, args|
    email = args[:email] || abort("email required")
    password = args[:password] || abort("password required")

    user = User.find_by(email: email)

    if user&.authenticate(password)
      token = user.generate_token
      puts token
    else
      abort "invalid credentials"
    end
  end

  desc "renew a token"
  task :renew_token, [ :token ] => :environment do |_, args|
    token = args[:token] || abort("token required")

    user = User.from_token(token)

    if user
      new_token = user.generate_token
      puts new_token
    else
      abort "invalid token"
    end
  end

  desc "get user info from token"
  task :info, [ :token ] => :environment do |_, args|
    token = args[:token] || abort("token required")

    user = User.from_token(token)

    if user
      puts "id: #{user.id}"
      puts "email: #{user.email}"
      puts "created_at: #{user.created_at}"

      # Get subscription info if available
      subscriptions = user.subscriptions.where(status: "active")
      if subscriptions.any?
        puts "active subscriptions:"
        subscriptions.each do |subscription|
          puts "  plan: #{subscription.plan_name}"
          puts "  expires: #{subscription.current_period_end}"
        end
      else
        puts "no active subscriptions"
      end
    else
      abort "invalid token"
    end
  end

  desc "list all users"
  task list: :environment do
    users = User.all

    if users.any?
      puts "users (#{users.count}):"
      users.each do |user|
        puts "  id: #{user.id}, email: #{user.email}, created: #{user.created_at}"
      end
    else
      puts "no users found"
    end
  end
end
