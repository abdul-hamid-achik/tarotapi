require 'rails_helper'

# Create a test controller to test the concern
class TestAuthController < ApplicationController
  include AuthenticateRequest

  def authenticated_action
    render json: { user_id: current_user.id, message: "Authenticated" }
  end
end

# Configure routes for testing
Rails.application.routes.draw do
  get 'test_auth/authenticated_action', to: 'test_auth#authenticated_action'
end

RSpec.describe AuthenticateRequest, type: :controller do
  controller(TestAuthController) do
  end

  let(:user) { create(:user, :registered) }
  let(:agent_user) { create(:user, :agent) }
  let!(:api_key) { create(:api_key, user: user) }
  let!(:agent_api_key) { create(:api_key, user: agent_user) }

  before do
    routes.draw { get 'authenticated_action' => 'test_auth#authenticated_action' }

    # Stub the devise token auth method
    allow_any_instance_of(TestAuthController).to receive(:set_user_by_token) do |controller|
      controller.instance_variable_set(:@resource, nil)
    end
  end

  describe "without authentication" do
    it "returns unauthorized when no authentication is provided" do
      get :authenticated_action
      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body)['error']).to eq('unauthorized')
    end
  end

  describe "API key authentication" do
    it "authenticates with a valid API key" do
      request.headers['X-API-Key'] = api_key.token

      get :authenticated_action

      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body)['user_id']).to eq(user.id)
      expect(assigns(:current_api_key)).to eq(api_key)
    end

    it "rejects invalid API keys" do
      request.headers['X-API-Key'] = 'invalid-api-key'

      get :authenticated_action

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "HTTP Basic authentication" do
    it "authenticates with valid HTTP Basic credentials for registered users" do
      # Stub User.find_by to return our test user
      allow(User).to receive(:find_by).with(email: user.email).and_return(user)
      # Stub valid_password? to return true for our test
      allow(user).to receive(:valid_password?).and_return(true)
      # Stub registered? to return true
      allow(user).to receive(:registered?).and_return(true)

      # Create HTTP Basic Auth header
      credentials = ActionController::HttpAuthentication::Basic.encode_credentials(user.email, 'password')
      request.headers['Authorization'] = credentials

      get :authenticated_action

      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body)['user_id']).to eq(user.id)
    end

    it "authenticates agent users with both HTTP Basic and API key" do
      # Stub User.find_by to return our agent user
      allow(User).to receive(:find_by).with(email: agent_user.email).and_return(agent_user)
      # Stub valid_password? to return true for our test
      allow(agent_user).to receive(:valid_password?).and_return(true)
      # Stub agent? to return true
      allow(agent_user).to receive(:agent?).and_return(true)
      # Stub api_keys association
      allow(agent_user).to receive(:api_keys).and_return(agent_user.api_keys)

      # Create HTTP Basic Auth header
      credentials = ActionController::HttpAuthentication::Basic.encode_credentials(agent_user.email, 'password')
      request.headers['Authorization'] = credentials
      request.headers['X-API-Key'] = agent_api_key.token

      get :authenticated_action

      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body)['user_id']).to eq(agent_user.id)
    end

    it "rejects agent users without API key" do
      # Stub User.find_by to return our agent user
      allow(User).to receive(:find_by).with(email: agent_user.email).and_return(agent_user)
      # Stub valid_password? to return true for our test
      allow(agent_user).to receive(:valid_password?).and_return(true)
      # Stub agent? to return true
      allow(agent_user).to receive(:agent?).and_return(true)

      # Create HTTP Basic Auth header without API key
      credentials = ActionController::HttpAuthentication::Basic.encode_credentials(agent_user.email, 'password')
      request.headers['Authorization'] = credentials

      get :authenticated_action

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "token authentication" do
    it "attempts to authenticate with token via devise_token_auth" do
      # Stub the devise token auth method to set a user
      allow_any_instance_of(TestAuthController).to receive(:set_user_by_token) do |controller|
        controller.instance_variable_set(:@resource, user)
      end

      request.headers['Authorization'] = 'Bearer fake-token'

      get :authenticated_action

      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body)['user_id']).to eq(user.id)
    end
  end

  describe "authentication order" do
    it "tries token before API key before HTTP Basic auth" do
      # We'll set up all three authentication methods and verify the order

      # First, set up a spy on authenticate_with_token
      allow_any_instance_of(TestAuthController).to receive(:authenticate_with_token).and_call_original

      # Next, set up a spy on authenticate_with_api_key
      allow_any_instance_of(TestAuthController).to receive(:authenticate_with_api_key).and_call_original

      # Finally, set up a spy on authenticate_with_http_basic
      allow_any_instance_of(TestAuthController).to receive(:authenticate_with_http_basic).and_call_original

      # Now make a request with no authentication
      get :authenticated_action

      # Verify the order of calls
      expect(controller).to have_received(:authenticate_with_token).ordered
      expect(controller).to have_received(:authenticate_with_api_key).ordered
      expect(controller).to have_received(:authenticate_with_http_basic).ordered
    end
  end
end
