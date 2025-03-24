require 'json'

# Setup Steps

Given("there is a registered api client with id {string}") do |client_id|
  @client_secret = "#{client_id}_secret"

  unless ApiClient.exists?(client_id: client_id)
    ApiClient.create!(
      name: "Test Client",
      client_id: client_id,
      client_secret: @client_secret,
      redirect_uris: [ "https://client.example.com/cb" ],
      scopes: [ "read", "write" ]
    )
  end
end

Given("i have a valid authorization code {string} for client {string}") do |code, client_id|
  # First, make sure we have the client
  step "there is a registered api client with id \"#{client_id}\""

  # Create a new user if we don't have one already
  @user ||= User.create!(
    email: "oauth_test@example.com",
    password: "password",
    password_confirmation: "password"
  )

  # Create an authorization record
  @authorization = Authorization.create!(
    user: @user,
    client_id: client_id,
    code: code,
    scope: "read,write",
    expires_at: 10.minutes.from_now
  )
end

Given("i have an expired authorization code {string} for client {string}") do |code, client_id|
  # First, make sure we have the client
  step "there is a registered api client with id \"#{client_id}\""

  # Create a new user if we don't have one already
  @user ||= User.create!(
    email: "oauth_test@example.com",
    password: "password",
    password_confirmation: "password"
  )

  # Create an expired authorization record
  @authorization = Authorization.create!(
    user: @user,
    client_id: client_id,
    code: code,
    scope: "read,write",
    expires_at: 10.minutes.ago # Expired
  )
end

# Action Steps

When("i request authorization with valid parameters") do |table|
  data = table.hashes.first
  @request_payload = data

  @response = get "/api/v1/oauth/authorize", params: data, headers: {
    'Content-Type': 'application/json',
    'Authorization': "Bearer #{@token}" # Use token if authenticated
  }
  @response_body = JSON.parse(@response.body) rescue {}
end

When("i request authorization with invalid parameters") do |table|
  data = table.hashes.first
  @request_payload = data

  @response = get "/api/v1/oauth/authorize", params: data, headers: {
    'Content-Type': 'application/json'
  }
  @response_body = JSON.parse(@response.body) rescue {}
end

When("i request authorization with an invalid client id") do |table|
  data = table.hashes.first
  @request_payload = data

  @response = get "/api/v1/oauth/authorize", params: data, headers: {
    'Content-Type': 'application/json'
  }
  @response_body = JSON.parse(@response.body) rescue {}
end

When("i request an access token with the authorization code") do |table|
  data = table.hashes.first
  @request_payload = data

  @response = post "/api/v1/oauth/token", params: data, headers: {
    'Content-Type': 'application/json'
  }
  @response_body = JSON.parse(@response.body) rescue {}
end

When("i request an access token with invalid grant type") do |table|
  data = table.hashes.first
  @request_payload = data

  @response = post "/api/v1/oauth/token", params: data, headers: {
    'Content-Type': 'application/json'
  }
  @response_body = JSON.parse(@response.body) rescue {}
end

# Assertion Steps

Then("the response should contain a redirect link if not authenticated") do
  if @token.nil?
    expect(@response_body).to have_key("redirect_to")
    expect(@response_body).to have_key("oauth_params")
  end
end

Then("the response should contain an authorization code") do
  expect(@response_body).to have_key("code")
  expect(@response_body["code"]).to be_a(String)
  expect(@response_body["code"].length).to be > 0
end

Then("the response should include the state parameter") do
  expect(@response_body).to have_key("state")
  expect(@response_body["state"]).to eq(@request_payload["state"])
end

Then("the response should contain an error {string}") do |error_code|
  expect(@response_body).to have_key("error")
  expect(@response_body["error"]).to eq(error_code)
end

Then("the response should contain an access token") do
  expect(@response_body).to have_key("access_token")
  expect(@response_body["access_token"]).to be_a(String)
  expect(@response_body["access_token"].length).to be > 0
end

Then("the response should contain a refresh token") do
  expect(@response_body).to have_key("refresh_token")
  expect(@response_body["refresh_token"]).to be_a(String)
  expect(@response_body["refresh_token"].length).to be > 0
end

Then("the response should include token expiration") do
  expect(@response_body).to have_key("expires_in")
  expect(@response_body["expires_in"]).to be_a(Integer)
  expect(@response_body["expires_in"]).to be > 0
end
