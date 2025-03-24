require 'json'

# Setup Steps

Given("i am authenticated as an admin") do
  # First create an admin user
  @admin_user = User.create!(
    email: "admin@example.com",
    password: "admin_password",
    password_confirmation: "admin_password",
    role: "admin"
  )

  # Login with admin credentials
  @request_payload = { email: "admin@example.com", password: "admin_password" }
  @response = post "/api/v1/auth/login", params: @request_payload.to_json, headers: { 'Content-Type': 'application/json' }
  @response_body = JSON.parse(@response.body) rescue {}

  # Save the tokens for later use
  @token = @response_body["token"]
  @client = @response_body["client"]
  @uid = @response_body["uid"]
end

Given("i am authenticated as a regular user") do
  # Use the existing step for regular authentication
  step 'i am authenticated'
end

Given("the system is experiencing database connection issues") do
  # Mock the DatabaseHealthcheck class to simulate database issues
  module ::DatabaseHealthcheck
    class << self
      alias_method :original_check_connection, :check_connection if method_defined?(:check_connection)

      def check_connection
        false # Simulate connection failure
      end
    end
  end

  # Ensure we clean up after the test
  After do
    if defined?(::DatabaseHealthcheck) && ::DatabaseHealthcheck.singleton_class.method_defined?(:original_check_connection)
      module ::DatabaseHealthcheck
        class << self
          alias_method :check_connection, :original_check_connection
          remove_method :original_check_connection
        end
      end
    end
  end
end

Given("the database connection pool is heavily utilized") do
  # Mock the connection pool to simulate high utilization
  module ActiveRecord
    class ConnectionPool
      alias_method :original_connections, :connections if method_defined?(:connections)

      def connections
        # Return a collection of mock connections where most are in use
        Array.new(size).map do |i|
          mock_connection = OpenStruct.new
          mock_connection.define_singleton_method(:in_use?) { i < (size * 0.9) } # 90% utilization
          mock_connection
        end
      end
    end
  end

  # Ensure we clean up after the test
  After do
    if defined?(ActiveRecord::ConnectionPool) && ActiveRecord::ConnectionPool.method_defined?(:original_connections)
      ActiveRecord::ConnectionPool.class_eval do
        alias_method :connections, :original_connections
        remove_method :original_connections
      end
    end
  end
end

# Action Steps

When("i request the detailed health status") do
  @response = get "/api/v1/health/detailed", headers: {
    'Content-Type': 'application/json',
    'Authorization': "Bearer #{@token}"
  }
  @response_body = JSON.parse(@response.body) rescue {}
end

When("i request the database health status") do
  @response = get "/api/v1/health/database", headers: {
    'Content-Type': 'application/json',
    'Authorization': "Bearer #{@token}"
  }
  @response_body = JSON.parse(@response.body) rescue {}
end

When("i try to access the detailed health status") do
  @response = get "/api/v1/health/detailed", headers: {
    'Content-Type': 'application/json',
    'Authorization': "Bearer #{@token}"
  }
  @response_body = JSON.parse(@response.body) rescue {}
end

When("i try to access the database health status") do
  @response = get "/api/v1/health/database", headers: {
    'Content-Type': 'application/json',
    'Authorization': "Bearer #{@token}"
  }
  @response_body = JSON.parse(@response.body) rescue {}
end

When("i try to access the detailed health status without authentication") do
  @response = get "/api/v1/health/detailed", headers: { 'Content-Type': 'application/json' }
  @response_body = JSON.parse(@response.body) rescue {}
end

# Assertion Steps

Then("the response should contain overall system status") do
  expect(@response_body).to have_key("status")
  expect(@response_body["status"]).to be_a(String)
end

Then("the response should contain component statuses") do
  expect(@response_body).to have_key("components")
  expect(@response_body["components"]).to be_a(Hash)
  expect(@response_body["components"]).to have_key("database")
  expect(@response_body["components"]).to have_key("redis")
end

Then("the response should include database pool statistics") do
  if @response_body.has_key?("components")
    expect(@response_body["components"]["database"]).to have_key("pool")
    expect(@response_body["components"]["database"]["pool"]).to be_a(Hash)
  else
    expect(@response_body).to have_key("pool")
    expect(@response_body["pool"]).to be_a(Hash)
  end
end

Then("the response should include redis pool statistics") do
  expect(@response_body["components"]["redis"]).to have_key("pool")
  expect(@response_body["components"]["redis"]["pool"]).to be_a(Hash)
end

Then("the response should contain database status") do
  expect(@response_body).to have_key("status")
  expect(@response_body["status"]).to be_a(String)
end

Then("the response should include database version information") do
  expect(@response_body).to have_key("database")
  expect(@response_body["database"]).to be_a(Hash)
  expect(@response_body["database"]).to have_key("version")
end

Then("i should receive a response with status {int}") do |status_code|
  expect(@response.status).to eq(status_code)
end

Then("the response should indicate degraded system status") do
  expect(@response_body["status"]).to eq("degraded")
end

Then("the response should identify the problematic component") do
  # In our example, the database component should be marked as having an error
  expect(@response_body["components"]["database"]["status"]).to eq("error")
end

Then("the response should indicate a warning for the database pool") do
  # This might be in different places depending on the endpoint
  if @response_body.has_key?("components")
    expect(@response_body["components"]["database"]["pool_status"]).to eq("warning")
  else
    expect(@response_body["status"]).to eq("warning")
  end
end

Then("the response should show high usage percentage") do
  # Check pool stats for high usage
  pool_stats = if @response_body.has_key?("components")
               @response_body["components"]["database"]["pool"]
  else
               @response_body["pool"]
  end

  expect(pool_stats).to have_key("usage_percent")
  expect(pool_stats["usage_percent"].to_f).to be > 80 # High usage is > 80%
end
