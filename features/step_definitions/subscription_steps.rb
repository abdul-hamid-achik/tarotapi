require 'json'

# Setup Steps

Given("i have an active subscription") do
  # Create a subscription in the test database
  plan = SubscriptionPlan.find_or_create_by(name: "basic")
  @subscription = Subscription.create!(
    user: @user,
    subscription_plan: plan,
    status: "active",
    processor_id: "sub_test_123",
    ends_at: 30.days.from_now
  )
end

Given("i have an active subscription with plan {string}") do |plan_name|
  plan = SubscriptionPlan.find_or_create_by(name: plan_name)
  @subscription = Subscription.create!(
    user: @user,
    subscription_plan: plan,
    status: "active",
    processor_id: "sub_test_#{plan_name}",
    ends_at: 30.days.from_now
  )
end

Given("i have a canceled subscription that has not expired") do
  plan = SubscriptionPlan.find_or_create_by(name: "basic")
  @subscription = Subscription.create!(
    user: @user,
    subscription_plan: plan,
    status: "canceled",
    processor_id: "sub_test_canceled",
    ends_at: 30.days.from_now # Still has access until the end of the period
  )
end

Given("i have a payment method") do
  # Mock having a payment method on the user's account
  # This is usually handled by the payment processor (Stripe)
  # For testing, we'll just set up a flag
  @has_payment_method = true
end

Given("i have a non-default payment method") do
  @payment_method_id = "pm_non_default_123"
  # Setup would occur through Stripe API in real implementation
  # For testing, assume we have this set up
end

Given("i have a default payment method") do
  @default_payment_method_id = "pm_default_123"
  # Setup would occur through Stripe API in real implementation
  # For testing, assume we have this set up
end

Given("i have multiple payment methods") do
  @payment_method_ids = [ "pm_123", "pm_456", "pm_789" ]
  @removable_payment_method_id = @payment_method_ids.last
  # Setup would occur through Stripe API in real implementation
  # For testing, assume we have these set up
end

# Action Steps

When("i request my subscriptions") do
  @response = get "/api/v1/subscriptions", headers: {
    'Content-Type': 'application/json',
    'Authorization': "Bearer #{@token}"
  }
  @response_body = JSON.parse(@response.body) rescue {}
end

When("i request subscription details") do
  @response = get "/api/v1/subscriptions/#{@subscription.id}", headers: {
    'Content-Type': 'application/json',
    'Authorization': "Bearer #{@token}"
  }
  @response_body = JSON.parse(@response.body) rescue {}
end

When("i subscribe to a plan with name {string}") do |plan_name|
  @request_payload = { plan_name: plan_name }
  @response = post "/api/v1/subscriptions", params: @request_payload.to_json, headers: {
    'Content-Type': 'application/json',
    'Authorization': "Bearer #{@token}"
  }
  @response_body = JSON.parse(@response.body) rescue {}
end

When("i cancel my subscription") do
  @response = post "/api/v1/subscriptions/#{@subscription.id}/cancel", headers: {
    'Content-Type': 'application/json',
    'Authorization': "Bearer #{@token}"
  }
  @response_body = JSON.parse(@response.body) rescue {}
end

When("i change my plan to {string}") do |plan_name|
  @request_payload = { plan_name: plan_name }
  @response = post "/api/v1/subscriptions/#{@subscription.id}/change_plan", params: @request_payload.to_json, headers: {
    'Content-Type': 'application/json',
    'Authorization': "Bearer #{@token}"
  }
  @response_body = JSON.parse(@response.body) rescue {}
end

When("i reactivate my subscription") do
  @response = post "/api/v1/subscriptions/#{@subscription.id}/reactivate", headers: {
    'Content-Type': 'application/json',
    'Authorization': "Bearer #{@token}"
  }
  @response_body = JSON.parse(@response.body) rescue {}
end

When("i request my payment methods") do
  @response = get "/api/v1/subscriptions/payment_methods", headers: {
    'Content-Type': 'application/json',
    'Authorization': "Bearer #{@token}"
  }
  @response_body = JSON.parse(@response.body) rescue {}
end

When("i add a new payment method with id {string}") do |payment_method_id|
  @request_payload = { payment_method_id: payment_method_id }
  @response = post "/api/v1/subscriptions/payment_methods", params: @request_payload.to_json, headers: {
    'Content-Type': 'application/json',
    'Authorization': "Bearer #{@token}"
  }
  @response_body = JSON.parse(@response.body) rescue {}
end

When("i add a new payment method with id {string} as default") do |payment_method_id|
  @request_payload = { payment_method_id: payment_method_id, default: true }
  @response = post "/api/v1/subscriptions/payment_methods", params: @request_payload.to_json, headers: {
    'Content-Type': 'application/json',
    'Authorization': "Bearer #{@token}"
  }
  @response_body = JSON.parse(@response.body) rescue {}
end

When("i remove a non-default payment method") do
  @response = delete "/api/v1/subscriptions/payment_methods/#{@removable_payment_method_id}", headers: {
    'Content-Type': 'application/json',
    'Authorization': "Bearer #{@token}"
  }
  @response_body = JSON.parse(@response.body) rescue {}
end

When("i try to remove the default payment method") do
  @response = delete "/api/v1/subscriptions/payment_methods/#{@default_payment_method_id}", headers: {
    'Content-Type': 'application/json',
    'Authorization': "Bearer #{@token}"
  }
  @response_body = JSON.parse(@response.body) rescue {}
end

# Assertion Steps

Then("the response should contain a list of my subscriptions") do
  expect(@response_body).to be_an(Array)
end

Then("the response should contain subscription information") do
  expect(@response_body).to have_key("id")
  expect(@response_body).to have_key("plan_name")
end

Then("the response should include the subscription status") do
  expect(@response_body).to have_key("status")
end

Then("the response should include the current period end date") do
  expect(@response_body).to have_key("current_period_end")
end

Then("the response should contain subscription details") do
  expect(@response_body).to have_key("subscription_id")
  expect(@response_body).to have_key("status")
end

Then("the response should contain client secret for payment confirmation") do
  expect(@response_body).to have_key("client_secret")
end

Then("the response should indicate the subscription is canceled") do
  expect(@response_body).to have_key("status")
  expect(@response_body["status"]).to eq("canceled")
end

Then("the response should include the end date") do
  expect(@response_body).to have_key("ends_at")
end

Then("the response should indicate the new plan is {string}") do |plan_name|
  expect(@response_body).to have_key("plan_name")
  expect(@response_body["plan_name"]).to eq(plan_name)
end

Then("the response should indicate the subscription is active") do
  expect(@response_body).to have_key("status")
  expect(@response_body["status"]).to eq("active")
end

Then("the response should contain a list of my payment methods") do
  expect(@response_body).to be_an(Array)
  # If there are payment methods, check their structure
  unless @response_body.empty?
    expect(@response_body.first).to have_key("id")
    expect(@response_body.first).to have_key("last4")
  end
end

Then("the response should contain the payment method details") do
  expect(@response_body).to have_key("id")
  expect(@response_body).to have_key("type")
  expect(@response_body).to have_key("last4")
end

Then("the response should indicate the payment method is default") do
  expect(@response_body).to have_key("default")
  expect(@response_body["default"]).to be true
end

Then("the payment method should be removed") do
  expect(@response_body).to have_key("success")
  expect(@response_body["success"]).to be true
end

Then("the response should contain an error about default payment method") do
  expect(@response_body).to have_key("error")
  expect(@response_body["error"]).to include("default payment method")
end
