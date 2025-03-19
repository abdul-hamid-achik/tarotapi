namespace :subscriptions do
  desc "create a subscription for a user"
  task :create, [ :token, :plan ] => :environment do |_, args|
    token = args[:token] || abort("token required")
    plan = args[:plan] || abort("plan required")

    user = User.from_token(token)
    abort "invalid token" unless user

    puts "creating subscription for user #{user.email} with plan #{plan}..."

    begin
      # Set Stripe API key
      Stripe.api_key = ENV["STRIPE_SECRET_KEY"]

      # Get or create Stripe customer
      if user.stripe_customer_id.present?
        customer = Stripe::Customer.retrieve(user.stripe_customer_id)
      else
        customer = Stripe::Customer.create(email: user.email)
        user.update(stripe_customer_id: customer.id)
      end

      # Create subscription in Stripe
      subscription = Stripe::Subscription.create(
        customer: customer.id,
        items: [ { price: plan } ]
      )

      # Create subscription in database
      user_sub = user.subscriptions.create(
        stripe_id: subscription.id,
        stripe_customer_id: customer.id,
        plan_name: plan,
        status: subscription.status,
        current_period_start: Time.zone.at(subscription.current_period_start),
        current_period_end: Time.zone.at(subscription.current_period_end)
      )

      puts "subscription created successfully with id: #{user_sub.id}"
    rescue Stripe::StripeError => e
      abort "stripe error: #{e.message}"
    rescue => e
      abort "error: #{e.message}"
    end
  end

  desc "get subscription status for a user"
  task :status, [ :token ] => :environment do |_, args|
    token = args[:token] || abort("token required")

    user = User.from_token(token)
    abort "invalid token" unless user

    subscriptions = user.subscriptions.where(status: "active")

    if subscriptions.any?
      puts "active subscriptions for #{user.email}:"
      subscriptions.each do |subscription|
        puts "  id: #{subscription.id}"
        puts "  plan: #{subscription.plan_name}"
        puts "  status: #{subscription.status}"
        puts "  current period end: #{subscription.current_period_end}"
      end
    else
      puts "no active subscriptions for #{user.email}"
    end
  end

  desc "cancel a subscription"
  task :cancel, [ :token, :subscription_id ] => :environment do |_, args|
    token = args[:token] || abort("token required")
    subscription_id = args[:subscription_id] || abort("subscription_id required")

    user = User.from_token(token)
    abort "invalid token" unless user

    subscription = user.subscriptions.find_by(id: subscription_id)
    abort "subscription not found" unless subscription

    puts "canceling subscription #{subscription_id} for user #{user.email}..."

    if subscription.cancel!
      puts "subscription canceled successfully"
    else
      abort "failed to cancel subscription"
    end
  end

  desc "list all subscriptions"
  task list: :environment do
    subscriptions = Subscription.all.includes(:user)

    if subscriptions.any?
      puts "subscriptions (#{subscriptions.count}):"
      subscriptions.each do |subscription|
        puts "  id: #{subscription.id}, user: #{subscription.user.email}, plan: #{subscription.plan_name}, status: #{subscription.status}"
      end
    else
      puts "no subscriptions found"
    end
  end
end
