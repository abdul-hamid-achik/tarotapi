require 'json'

# Setup Steps

Given("i have a valid seance token") do
  # Create a token first
  @client_id = "valid-client-123"

  @response = post "/api/v1/seance", params: { client_id: @client_id }.to_json, headers: { 'Content-Type': 'application/json' }
  @response_body = JSON.parse(@response.body) rescue {}

  @token = @response_body["token"]
end

Given("i have an expired seance token") do
  # We would need to create an expired token
  # Since we can't directly manipulate time in the test environment easily,
  # We'll use a mock or specially crafted token that the system recognizes as expired
  @token = "eyJhbGciOiJIUzI1NiJ9.eyJjbGllbnRfaWQiOiJleHBpcmVkLWNsaWVudCIsImV4cCI6MTU3NzgzNjgwMH0.signature"
end

Given("i have a tampered seance token") do
  # Create a deliberately tampered token
  @token = "eyJhbGciOiJIUzI1NiJ9.eyJjbGllbnRfaWQiOiJ0YW1wZXJlZC1jbGllbnQiLCJleHAiOjk5OTk5OTk5OTl9.invalid_signature"
end

# Action Steps

When("i request a new seance token with client id {string}") do |client_id|
  @client_id = client_id
  @request_payload = { client_id: client_id }

  @response = post "/api/v1/seance", params: @request_payload.to_json, headers: { 'Content-Type': 'application/json' }
  @response_body = JSON.parse(@response.body) rescue {}
end

When("i request a new seance token without a client id") do
  @request_payload = {}

  @response = post "/api/v1/seance", params: @request_payload.to_json, headers: { 'Content-Type': 'application/json' }
  @response_body = JSON.parse(@response.body) rescue {}
end

When("i validate the seance token") do
  @response = get "/api/v1/seance/validate", headers: {
    'Content-Type': 'application/json',
    'X-Seance-Token': @token
  }
  @response_body = JSON.parse(@response.body) rescue {}
end

When("i validate without providing a token") do
  @response = get "/api/v1/seance/validate", headers: { 'Content-Type': 'application/json' }
  @response_body = JSON.parse(@response.body) rescue {}
end

# Assertion Steps

Then("the response should contain a seance token") do
  expect(@response_body).to have_key("token")
  expect(@response_body["token"]).to be_a(String)
  expect(@response_body["token"].length).to be > 0
end

Then("the response should include token expiration time") do
  expect(@response_body).to have_key("expires_at")
end

Then("the response should indicate the token is valid") do
  expect(@response_body).to have_key("valid")
  expect(@response_body["valid"]).to be true
end

Then("the response should include the client id") do
  expect(@response_body).to have_key("client_id")
  expect(@response_body["client_id"]).to eq(@client_id) if @client_id
end

Then("the response should indicate the token is invalid") do
  expect(@response_body).to have_key("valid")
  expect(@response_body["valid"]).to be false
end

Then("the response should contain an error about expiration") do
  expect(@response_body).to have_key("error")
  expect(@response_body["error"]).to include("expired")
end

Then("the response should contain an error about token validity") do
  expect(@response_body).to have_key("error")
  expect(@response_body["error"]).to include("invalid")
end
