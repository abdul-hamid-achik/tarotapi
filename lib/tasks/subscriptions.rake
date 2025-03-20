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

  desc "setup stripe webhook endpoints"
  task setup_webhooks: :environment do
    puts "setting up stripe webhook endpoints..."
    
    unless ENV["STRIPE_SECRET_KEY"]
      puts "error: STRIPE_SECRET_KEY environment variable is required"
      exit 1
    end

    begin
      require "stripe"
      Stripe.api_key = ENV["STRIPE_SECRET_KEY"]

      # create or update webhook endpoint
      webhook_url = ENV["STRIPE_WEBHOOK_URL"] || "#{ENV['APP_URL']}/api/v1/webhooks/stripe"
      
      endpoints = Stripe::WebhookEndpoint.list
      existing = endpoints.data.find { |e| e.url == webhook_url }

      webhook_events = [
        "customer.subscription.created",
        "customer.subscription.updated",
        "customer.subscription.deleted",
        "invoice.paid",
        "invoice.payment_failed"
      ]

      if existing
        puts "updating existing webhook endpoint..."
        endpoint = Stripe::WebhookEndpoint.update(
          existing.id,
          { enabled_events: webhook_events }
        )
      else
        puts "creating new webhook endpoint..."
        endpoint = Stripe::WebhookEndpoint.create(
          url: webhook_url,
          enabled_events: webhook_events
        )
      end

      puts "✅ webhook endpoint configured: #{endpoint.url}"
      puts "webhook signing secret: #{endpoint.secret}"
      puts "make sure to set STRIPE_WEBHOOK_SECRET in your environment"
    rescue => e
      puts "❌ failed to setup webhook: #{e.message}"
      exit 1
    end
  end

  desc "sync stripe products and prices"
  task sync_products: :environment do
    puts "syncing stripe products and prices..."
    
    unless ENV["STRIPE_SECRET_KEY"]
      puts "error: STRIPE_SECRET_KEY environment variable is required"
      exit 1
    end

    begin
      require "stripe"
      Stripe.api_key = ENV["STRIPE_SECRET_KEY"]

      # sync products
      Stripe::Product.list(active: true).each do |product|
        subscription_plan = SubscriptionPlan.find_or_initialize_by(stripe_product_id: product.id)
        subscription_plan.update!(
          name: product.name,
          description: product.description,
          active: product.active,
          metadata: product.metadata.to_h
        )

        # sync prices for this product
        Stripe::Price.list(product: product.id, active: true).each do |price|
          subscription_price = subscription_plan.prices.find_or_initialize_by(stripe_price_id: price.id)
          subscription_price.update!(
            amount: price.unit_amount,
            currency: price.currency,
            interval: price.recurring&.interval,
            interval_count: price.recurring&.interval_count,
            active: price.active,
            metadata: price.metadata.to_h
          )
        end
      end

      puts "✅ successfully synced products and prices"
    rescue => e
      puts "❌ failed to sync products: #{e.message}"
      exit 1
    end
  end

  desc "check subscription statuses"
  task check_statuses: :environment do
    puts "checking subscription statuses..."

    User.find_each do |user|
      next unless user.stripe_customer_id

      begin
        require "stripe"
        Stripe.api_key = ENV["STRIPE_SECRET_KEY"]

        subscriptions = Stripe::Subscription.list(customer: user.stripe_customer_id)
        active_subscription = subscriptions.data.find { |s| s.status == "active" }

        if active_subscription
          user.update!(
            subscription_status: "active",
            subscription_end_date: Time.at(active_subscription.current_period_end)
          )
          puts "✓ user #{user.id}: active subscription until #{user.subscription_end_date}"
        else
          user.update!(subscription_status: "inactive", subscription_end_date: nil)
          puts "✗ user #{user.id}: no active subscription"
        end
      rescue => e
        puts "! error checking user #{user.id}: #{e.message}"
      end
    end
  end

  desc "reset usage counters for unlimited plans"
  task reset_usage: :environment do
    puts "resetting usage counters for unlimited plans..."

    User.where(subscription_status: "active").find_each do |user|
      if user.has_unlimited_plan?
        # Reset the usage flag for all reading sessions
        Reading.where(user: user).update_all(usage_counted: false)
        
        # Calculate readings count
        readings_count = user.readings.where(usage_counted: true).count
        puts "✓ reset usage counter for user #{user.id} with #{readings_count} readings"
      end
    end
  end

  desc "audit subscription usage"
  task audit_usage: :environment do
    puts "auditing subscription usage..."

    User.where(subscription_status: "active").find_each do |user|
      readings_count = user.readings.where(usage_counted: true).count
      plan_limit = user.subscription_plan&.reading_limit

      if plan_limit && readings_count > plan_limit
        puts "! user #{user.id} has exceeded their plan limit (#{readings_count}/#{plan_limit})"
      else
        puts "✓ user #{user.id} usage: #{readings_count}/#{plan_limit || 'unlimited'}"
      end
    end
  end

  desc "setup all subscription components"
  task setup: :environment do
    puts "setting up all subscription components..."

    Rake::Task["subscriptions:setup_webhooks"].invoke
    Rake::Task["subscriptions:sync_products"].invoke
    puts "✅ subscription setup completed"
  end
end
