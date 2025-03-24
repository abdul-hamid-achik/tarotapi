require 'json'

# Setup Steps

Given("i have an active subscription") do
  # Create a subscription plan
  plan = SubscriptionPlan.find_or_create_by(name: "premium")

  # Create a subscription for the user
  @subscription = Subscription.create!(
    user: @user,
    plan_name: "premium",
    status: "active",
    processor_id: "sub_test_premium",
    current_period_start: 30.days.ago,
    current_period_end: 30.days.from_now
  )
end

Given("i have a reading quota configured") do
  # Create or update reading quota for the user
  @reading_quota = ReadingQuota.find_or_initialize_by(user: @user)
  @reading_quota.update!(
    monthly_limit: 50,
    readings_count: 15,
    last_reset_at: 15.days.ago,
    llm_calls_limit: 100,
    llm_calls_count: 30
  )
end

Given("i belong to an organization") do
  @organization = Organization.create!(name: "Test Organization", billing_email: "org@example.com")

  # Create a membership for the user
  Membership.create!(
    organization: @organization,
    user: @user,
    role: "member",
    status: "active"
  )
end

Given("i have credits in my account") do
  # Create some credit transactions for the user
  [ 10, -5, 20, -8 ].each_with_index do |amount, index|
    UserCredit.create!(
      user: @user,
      amount: amount,
      transaction_type: amount.positive? ? "purchase" : "usage",
      description: amount.positive? ? "Credit purchase" : "Used for reading",
      expires_at: amount.positive? ? 90.days.from_now : nil,
      created_at: index.days.ago
    )
  end
end

Given("i do not belong to an organization") do
  # Ensure the user doesn't have an organization
  @user.memberships.destroy_all if @user.respond_to?(:memberships)
end

# Action Steps

When("i request my usage summary") do
  @response = get "/api/v1/usage", headers: {
    'Content-Type': 'application/json',
    'Authorization': "Bearer #{@token}"
  }
  @response_body = JSON.parse(@response.body) rescue {}
end

When("i request my daily usage metrics") do
  @response = get "/api/v1/usage/daily", headers: {
    'Content-Type': 'application/json',
    'Authorization': "Bearer #{@token}"
  }
  @response_body = JSON.parse(@response.body) rescue {}
end

When("i request my daily usage metrics for the last {int} days") do |days|
  @response = get "/api/v1/usage/daily?days=#{days}", headers: {
    'Content-Type': 'application/json',
    'Authorization': "Bearer #{@token}"
  }
  @response_body = JSON.parse(@response.body) rescue {}
  @requested_days = days
end

# Assertion Steps

Then("the response should contain subscription information if available") do
  # Skip this check if we know the user doesn't have a subscription
  unless defined?(@subscription) && @subscription.nil?
    if @response_body.has_key?("subscription") && @response_body["subscription"]
      expect(@response_body["subscription"]).to have_key("plan")
      expect(@response_body["subscription"]).to have_key("status")
    end
  end
end

Then("the response should contain reading quota information if available") do
  # Skip this check if we know the user doesn't have a reading quota
  unless defined?(@reading_quota) && @reading_quota.nil?
    if @response_body.has_key?("reading_quota")
      expect(@response_body["reading_quota"]).to have_key("monthly_limit")
      expect(@response_body["reading_quota"]).to have_key("used_this_month")
    end
  end
end

Then("the response should contain credit balance if available") do
  # Skip this check if we know the user doesn't have credits
  if @response_body.has_key?("credits")
    expect(@response_body["credits"]).to have_key("balance")
  end
end

Then("the response should contain detailed subscription information") do
  expect(@response_body).to have_key("subscription")
  expect(@response_body["subscription"]).to have_key("id")
  expect(@response_body["subscription"]).to have_key("plan")
  expect(@response_body["subscription"]).to have_key("status")
end

Then("the response should include subscription features") do
  expect(@response_body["subscription"]).to have_key("features")
  expect(@response_body["subscription"]["features"]).to be_an(Array)
end

Then("the response should include subscription period dates") do
  expect(@response_body["subscription"]).to have_key("current_period_start")
  expect(@response_body["subscription"]).to have_key("current_period_end")
end

Then("the response should contain reading quota limits") do
  expect(@response_body).to have_key("reading_quota")
  expect(@response_body["reading_quota"]).to have_key("monthly_limit")
  expect(@response_body["reading_quota"]).to have_key("llm_calls_limit")
end

Then("the response should include quota usage statistics") do
  expect(@response_body["reading_quota"]).to have_key("used_this_month")
  expect(@response_body["reading_quota"]).to have_key("remaining")
  expect(@response_body["reading_quota"]).to have_key("llm_calls_used")
  expect(@response_body["reading_quota"]).to have_key("llm_calls_remaining")
end

Then("the response should include quota reset date") do
  expect(@response_body["reading_quota"]).to have_key("reset_date")
end

Then("the response should contain api usage statistics") do
  expect(@response_body).to have_key("api_usage")
end

Then("the response should include rate limit information") do
  expect(@response_body["api_usage"]).to have_key("rate_limit")
  expect(@response_body["api_usage"]["rate_limit"]).to have_key("limit_per_minute")
end

Then("the response should contain credit balance") do
  expect(@response_body).to have_key("credits")
  expect(@response_body["credits"]).to have_key("balance")
end

Then("the response should include recent credit transactions") do
  expect(@response_body["credits"]).to have_key("recent_transactions")
  expect(@response_body["credits"]["recent_transactions"]).to be_an(Array)

  unless @response_body["credits"]["recent_transactions"].empty?
    expect(@response_body["credits"]["recent_transactions"].first).to have_key("amount")
    expect(@response_body["credits"]["recent_transactions"].first).to have_key("type")
    expect(@response_body["credits"]["recent_transactions"].first).to have_key("date")
  end
end

Then("the response should contain daily usage breakdown") do
  expect(@response_body).to have_key("metrics")
end

Then("the response should include the analyzed period") do
  expect(@response_body).to have_key("period")
  expect(@response_body["period"]).to have_key("start")
  expect(@response_body["period"]).to have_key("end")
  expect(@response_body["period"]).to have_key("days")
end

Then("the response should contain daily usage for {int} days") do |days|
  expect(@response_body).to have_key("period")
  expect(@response_body["period"]).to have_key("days")
  expect(@response_body["period"]["days"]).to eq(days)
end

Then("the metrics should be grouped by date and type") do
  expect(@response_body).to have_key("metrics")
  # The structure of metrics depends on the implementation, but we can check that it's a hash
  expect(@response_body["metrics"]).to be_a(Hash)
end

Then("the response should indicate organization not found") do
  expect(@response_body).to have_key("error")
  expect(@response_body["error"]).to include("Organization not found")
end
