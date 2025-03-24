require 'json'

Given("there is a registered user with email {string} and password {string}") do |email, password|
  @user = User.create!(
    email: email,
    password: password,
    password_confirmation: password,
    provider: "email",
    uid: email,
    identity_provider: IdentityProvider.registered
  )
end

When("i register with valid credentials") do |table|
  data = table.hashes.first
  @request_payload = { user: data }
  @response = post "/api/v1/auth/register", params: @request_payload.to_json, headers: { 'Content-Type': 'application/json' }
  @response_body = JSON.parse(@response.body) rescue {}
end

When("i register with invalid credentials") do |table|
  data = table.hashes.first
  @request_payload = { user: data }
  @response = post "/api/v1/auth/register", params: @request_payload.to_json, headers: { 'Content-Type': 'application/json' }
  @response_body = JSON.parse(@response.body) rescue {}
end

When("i login with email {string} and password {string}") do |email, password|
  @request_payload = { email: email, password: password }
  @response = post "/api/v1/auth/login", params: @request_payload.to_json, headers: { 'Content-Type': 'application/json' }
  @response_body = JSON.parse(@response.body) rescue {}

  # Save the tokens for later use if login was successful
  if @response.successful?
    @token = @response_body["token"]
    @client = @response_body["client"]
    @uid = @response_body["uid"]
    @refresh_token = @response_body["refresh_token"]
  end
end

Given("i have a valid refresh token") do
  # First create a user and get their refresh token
  step 'there is a registered user with email "refresh@example.com" and password "refresh_password"'
  step 'i login with email "refresh@example.com" and password "refresh_password"'
  @refresh_token = @response_body["refresh_token"]
end

When("i request a token refresh") do
  @request_payload = { refresh_token: @refresh_token }
  @response = post "/api/v1/auth/refresh", params: @request_payload.to_json, headers: { 'Content-Type': 'application/json' }
  @response_body = JSON.parse(@response.body) rescue {}
end

When("i request a token refresh with an invalid token") do
  @request_payload = { refresh_token: "invalid_refresh_token" }
  @response = post "/api/v1/auth/refresh", params: @request_payload.to_json, headers: { 'Content-Type': 'application/json' }
  @response_body = JSON.parse(@response.body) rescue {}
end

Given("i am authenticated") do
  step 'there is a registered user with email "authenticated@example.com" and password "auth_password"'
  step 'i login with email "authenticated@example.com" and password "auth_password"'
end

Given("i am authenticated as a registered user") do
  step 'i am authenticated'
end

When("i request my profile") do
  @response = get "/api/v1/auth/profile", headers: {
    'Content-Type': 'application/json',
    'Authorization': "Bearer #{@token}",
    'client': @client,
    'uid': @uid
  }
  @response_body = JSON.parse(@response.body) rescue {}
end

When("i request my profile without authentication") do
  @response = get "/api/v1/auth/profile", headers: { 'Content-Type': 'application/json' }
  @response_body = JSON.parse(@response.body) rescue {}
end

When("i create an agent with valid credentials") do |table|
  data = table.hashes.first
  @request_payload = data
  @response = post "/api/v1/auth/create_agent", params: @request_payload.to_json, headers: {
    'Content-Type': 'application/json',
    'Authorization': "Bearer #{@token}",
    'client': @client,
    'uid': @uid
  }
  @response_body = JSON.parse(@response.body) rescue {}
end

When("i create an agent without authentication") do
  @request_payload = {
    email: "unauthenticated_agent@example.com",
    password: "unauthenticated",
    password_confirmation: "unauthenticated"
  }
  @response = post "/api/v1/auth/create_agent", params: @request_payload.to_json, headers: { 'Content-Type': 'application/json' }
  @response_body = JSON.parse(@response.body) rescue {}
end

Then("i should receive a success response with status {int}") do |status_code|
  expect(@response.status).to eq(status_code)
end

Then("i should receive a success response") do
  expect(@response.successful?).to be_truthy
end

Then("i should receive an error response with status {int}") do |status_code|
  expect(@response.status).to eq(status_code)
end

Then("the response should contain a token") do
  expect(@response_body).to have_key("token")
  expect(@response_body["token"]).not_to be_nil
end

Then("the response should contain refresh token") do
  expect(@response_body).to have_key("refresh_token")
  expect(@response_body["refresh_token"]).not_to be_nil
end

Then("the response should contain a new token") do
  expect(@response_body).to have_key("token")
  expect(@response_body["token"]).not_to be_nil

  # Check that it's a different token from the one we had before
  expect(@response_body["token"]).not_to eq(@token) if @token
end

Then("the response should contain user information") do
  expect(@response_body).to have_key("user")
  expect(@response_body["user"]).to have_key("id")
  expect(@response_body["user"]).to have_key("email")
end

Then("the response should contain my user information") do
  expect(@response_body).to have_key("id")
  expect(@response_body).to have_key("email")
  expect(@response_body).to have_key("identity_provider")
end

Then("the response should contain validation errors") do
  expect(@response_body).to have_key("errors")
  expect(@response_body["errors"]).to be_an(Array)
  expect(@response_body["errors"]).not_to be_empty
end

Then("the response should contain an error message {string}") do |message|
  expect(@response_body).to have_key("error")
  expect(@response_body["error"]).to eq(message)
end

Then("the response should contain agent information") do
  expect(@response_body).to have_key("agent_id")
  expect(@response_body).to have_key("external_id")
  expect(@response_body).to have_key("email")
end

Then("the response should contain agent token") do
  expect(@response_body).to have_key("token")
  expect(@response_body).to have_key("client")
  expect(@response_body).to have_key("uid")
end
