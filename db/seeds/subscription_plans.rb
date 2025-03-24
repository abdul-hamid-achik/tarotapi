# Create default subscription plans
require_relative '../../lib/tarot_logger'

TarotLogger.info("Creating default subscription plans...")

free_tier_limit = ENV.fetch("DEFAULT_FREE_TIER_LIMIT", 100).to_i
llm_calls_limit = ENV.fetch("DEFAULT_LLM_CALLS_LIMIT", 1000).to_i

# Free tier plan
SubscriptionPlan.find_or_create_by(name: "free") do |plan|
  plan.price_cents = 0
  plan.reading_limit = free_tier_limit
  plan.interval = "month"
  TarotLogger.info("Created FREE plan", { reading_limit: free_tier_limit, interval: "month" })
end

# Basic Subscription ($5.99/month)
SubscriptionPlan.find_or_create_by(name: "basic") do |plan|
  plan.price_cents = 599
  plan.reading_limit = 250
  plan.interval = "month"
  plan.features = [ "ad_free", "full_history", "basic_agent" ]
  TarotLogger.info("Created BASIC plan", { reading_limit: 250, price: "$5.99", interval: "month" })
end

# Premium Subscription ($12.99/month)
SubscriptionPlan.find_or_create_by(name: "premium") do |plan|
  plan.price_cents = 1299
  plan.reading_limit = nil # unlimited
  plan.interval = "month"
  plan.features = [ "ad_free", "full_history", "advanced_agent", "priority_access", "custom_spreads", "downloadable_reports" ]
  TarotLogger.info("Created PREMIUM plan", { reading_limit: "unlimited", price: "$12.99", interval: "month" })
end

# Professional API Plan ($19.95/month)
SubscriptionPlan.find_or_create_by(name: "professional") do |plan|
  plan.price_cents = 1995
  plan.reading_limit = nil # unlimited
  plan.interval = "month"
  plan.features = [ "ad_free", "full_history", "advanced_agent", "priority_access", "custom_spreads", "downloadable_reports", "priority_support", "api_access", "custom_integrations", "unlimited_llm" ]
  TarotLogger.info("Created PROFESSIONAL plan", { reading_limit: "unlimited", price: "$19.95", interval: "month", api_access: true })
end

# Define credit packages
credit_packages = [
  { name: "5 Credits", credits: 5, price_cents: 299, description: "Basic package of 5 reading credits" },
  { name: "10 Credits", credits: 10, price_cents: 499, description: "Standard package of 10 reading credits" },
  { name: "25 Credits", credits: 25, price_cents: 999, description: "Value package of 25 reading credits" },
  { name: "50 Credits", credits: 50, price_cents: 1799, description: "Premium package of 50 reading credits" }
]

# Store credit package information somewhere accessible to the application
# Since we don't have a dedicated model for packages yet, we'll store in Rails cache
if defined?(Rails.cache)
  Rails.cache.write('credit_packages', credit_packages, expires_in: 1.week)

  TarotLogger.info("Defined credit packages", { count: credit_packages.size })
  credit_packages.each do |package|
    TarotLogger.info("Credit package", {
      name: package[:name],
      credits: package[:credits],
      price: "$#{package[:price_cents].to_f / 100}"
    })
  end
end

TarotLogger.divine("Subscription plans creation complete", { plans_count: SubscriptionPlan.count })
