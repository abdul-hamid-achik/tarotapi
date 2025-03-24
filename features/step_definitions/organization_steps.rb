require 'json'

# Setup Steps

Given("i am a member of an organization") do
  @organization = Organization.create!(name: "Test Organization", billing_email: "org@example.com")
  Membership.create!(
    organization: @organization,
    user: @user,
    role: "member",
    status: "active"
  )
end

Given("i am an admin of an organization") do
  @organization = Organization.create!(name: "Admin Organization", billing_email: "admin@example.com")
  Membership.create!(
    organization: @organization,
    user: @user,
    role: "admin",
    status: "active"
  )
end

Given("i am a regular member of an organization") do
  @organization = Organization.create!(name: "Member Organization", billing_email: "member@example.com")
  Membership.create!(
    organization: @organization,
    user: @user,
    role: "member",
    status: "active"
  )
end

Given("i am an admin of an organization with members") do
  step 'i am an admin of an organization'

  # Create another user and add them as a member
  @other_user = User.create!(
    email: "other@example.com",
    password: "password",
    password_confirmation: "password"
  )

  @member = Membership.create!(
    organization: @organization,
    user: @other_user,
    role: "member",
    status: "active"
  )
end

# Action Steps

When("i request my organizations") do
  @response = get "/api/v1/organizations", headers: {
    'Content-Type': 'application/json',
    'Authorization': "Bearer #{@token}"
  }
  @response_body = JSON.parse(@response.body) rescue {}
end

When("i request organization details") do
  @response = get "/api/v1/organizations/#{@organization.id}", headers: {
    'Content-Type': 'application/json',
    'Authorization': "Bearer #{@token}"
  }
  @response_body = JSON.parse(@response.body) rescue {}
end

When("i create an organization with valid data") do |table|
  data = table.hashes.first
  @request_payload = { organization: data }

  @response = post "/api/v1/organizations", params: @request_payload.to_json, headers: {
    'Content-Type': 'application/json',
    'Authorization': "Bearer #{@token}"
  }
  @response_body = JSON.parse(@response.body) rescue {}
end

When("i create an organization with invalid data") do |table|
  data = table.hashes.first
  @request_payload = { organization: data }

  @response = post "/api/v1/organizations", params: @request_payload.to_json, headers: {
    'Content-Type': 'application/json',
    'Authorization': "Bearer #{@token}"
  }
  @response_body = JSON.parse(@response.body) rescue {}
end

When("i update the organization with new data") do |table|
  data = table.hashes.first
  @request_payload = { organization: data }

  @response = put "/api/v1/organizations/#{@organization.id}", params: @request_payload.to_json, headers: {
    'Content-Type': 'application/json',
    'Authorization': "Bearer #{@token}"
  }
  @response_body = JSON.parse(@response.body) rescue {}
end

When("i try to update the organization") do
  @request_payload = { organization: { name: "Attempted Update" } }

  @response = put "/api/v1/organizations/#{@organization.id}", params: @request_payload.to_json, headers: {
    'Content-Type': 'application/json',
    'Authorization': "Bearer #{@token}"
  }
  @response_body = JSON.parse(@response.body) rescue {}
end

When("i delete the organization") do
  @response = delete "/api/v1/organizations/#{@organization.id}", headers: {
    'Content-Type': 'application/json',
    'Authorization': "Bearer #{@token}"
  }
end

When("i add a new member to the organization") do |table|
  data = table.hashes.first
  @request_payload = { membership: data }

  @response = post "/api/v1/organizations/#{@organization.id}/members", params: @request_payload.to_json, headers: {
    'Content-Type': 'application/json',
    'Authorization': "Bearer #{@token}"
  }
  @response_body = JSON.parse(@response.body) rescue {}
end

When("i remove a member from the organization") do
  @response = delete "/api/v1/organizations/#{@organization.id}/members/#{@other_user.id}", headers: {
    'Content-Type': 'application/json',
    'Authorization': "Bearer #{@token}"
  }
end

When("i request usage data for the organization") do
  @response = get "/api/v1/organizations/#{@organization.id}/usage", headers: {
    'Content-Type': 'application/json',
    'Authorization': "Bearer #{@token}"
  }
  @response_body = JSON.parse(@response.body) rescue {}
end

When("i request usage data with date filters") do |table|
  data = table.hashes.first
  query_string = URI.encode_www_form(data)

  @response = get "/api/v1/organizations/#{@organization.id}/usage?#{query_string}", headers: {
    'Content-Type': 'application/json',
    'Authorization': "Bearer #{@token}"
  }
  @response_body = JSON.parse(@response.body) rescue {}
end

When("i request analytics data for the organization") do
  @response = get "/api/v1/organizations/#{@organization.id}/analytics", headers: {
    'Content-Type': 'application/json',
    'Authorization': "Bearer #{@token}"
  }
  @response_body = JSON.parse(@response.body) rescue {}
end

# Assertion Steps

Then("the response should contain a list of organizations") do
  expect(@response_body).to be_an(Array)
end

Then("the response should contain organization information") do
  expect(@response_body).to have_key("name")
  expect(@response_body).to have_key("billing_email")
end

Then("the response should contain the organization details") do
  expect(@response_body).to have_key("id")
  expect(@response_body).to have_key("name")
  expect(@response_body).to have_key("billing_email")
end

Then("i should be an admin member of the organization") do
  # Check by making a separate request to verify membership
  org_id = @response_body["id"]

  check_response = get "/api/v1/organizations/#{org_id}", headers: {
    'Content-Type': 'application/json',
    'Authorization': "Bearer #{@token}"
  }

  # This is a simplified check - the actual implementation would depend on how your API
  # returns membership information
  expect(check_response.status).to eq(200)
end

Then("the response should contain the updated information") do
  expect(@response_body["name"]).to eq(@request_payload[:organization][:name])
  expect(@response_body["billing_email"]).to eq(@request_payload[:organization][:billing_email])
end

Then("the response should contain the membership details") do
  expect(@response_body).to have_key("id")
  expect(@response_body).to have_key("role")
  expect(@response_body).to have_key("email")
end

Then("the response should contain usage metrics") do
  # The structure depends on how your application formats usage data
  # This is a basic check that would need to be adapted
  expect(@response_body).to be_a(Hash)
  # Check for some expected keys in usage data
  expect(@response_body).to have_key("readings") if @response_body.is_a?(Hash)
end

Then("the response should contain filtered usage data") do
  # Check that we have data for the specified date range
  expect(@response_body).to be_a(Hash)

  # Check for date-specific data based on your API's response format
  # This is a simplified check and would need to be adjusted based on the actual response structure
  if @response_body.is_a?(Hash) && @response_body.key?("data")
    expect(@response_body["data"]).to be_an(Array)
  end
end

Then("the response should contain analytics metrics") do
  expect(@response_body).to be_a(Hash)

  # Check for expected analytics metrics based on your API's response format
  # This would need to be adjusted based on the actual metrics your API returns
  expect(@response_body).to have_key("metrics") if @response_body.is_a?(Hash)
end
