# Create default subscription plans
puts "Creating default subscription plans..."

free_tier_limit = ENV.fetch("DEFAULT_FREE_TIER_LIMIT", 100).to_i

SubscriptionPlan.find_or_create_by(name: "free") do |plan|
  plan.price_cents = 0
  plan.reading_limit = free_tier_limit
  plan.interval = "month"
  puts "Created FREE plan with #{free_tier_limit} readings per month"
end

SubscriptionPlan.find_or_create_by(name: "premium") do |plan|
  plan.price_cents = 995
  plan.reading_limit = nil # unlimited
  plan.interval = "month"
  puts "Created PREMIUM plan with unlimited readings for $9.95/month"
end

SubscriptionPlan.find_or_create_by(name: "professional") do |plan|
  plan.price_cents = 1995
  plan.reading_limit = nil # unlimited
  plan.interval = "month"
  plan.features = ["priority_support", "api_access", "custom_integrations"]
  puts "Created PROFESSIONAL plan with unlimited readings and additional features for $19.95/month"
end

puts "Subscription plans created successfully!" 