require 'rails_helper'

# Create a test controller that includes the concern
class TestAuthController < ApplicationController
  include AuthenticateRequest

  def index
    render json: { user_id: current_user.id, authenticated: true }
  end
end

RSpec.describe AuthenticateRequest, type: :controller do
  # Use the test controller for our tests
  controller(TestAuthController) do
  end

  let(:user) { create(:user) }
  let(:agent_user) { create(:user, role: 'agent') }
  let(:api_key) { create(:api_key, user: user, token: 'valid-api-key-token') }
  let(:agent_api_key) { create(:api_key, user: agent_user, token: 'agent-api-key-token') }

  describe '#authenticate_request' do
    context 'with JWT token authentication' do
      before do
        allow(controller).to receive(:authenticate_with_token).and_return(user)
        allow(controller).to receive(:authenticate_with_api_key).and_return(nil)
        allow(controller).to receive(:authenticate_with_http_basic).and_return(nil)
      end

      it 'sets current_user from JWT token' do
        get :index
        expect(response).to have_http_status(:ok)
        expect(controller.instance_variable_get(:@current_user)).to eq(user)
        expect(JSON.parse(response.body)['user_id']).to eq(user.id)
      end
    end

    context 'with API key authentication' do
      before do
        allow(controller).to receive(:authenticate_with_token).and_return(nil)
        allow(controller).to receive(:authenticate_with_api_key).and_return(user)
        allow(controller).to receive(:authenticate_with_http_basic).and_return(nil)
      end

      it 'sets current_user from API key' do
        get :index
        expect(response).to have_http_status(:ok)
        expect(controller.instance_variable_get(:@current_user)).to eq(user)
      end
    end

    context 'with HTTP Basic authentication' do
      before do
        allow(controller).to receive(:authenticate_with_token).and_return(nil)
        allow(controller).to receive(:authenticate_with_api_key).and_return(nil)
        allow(controller).to receive(:authenticate_with_http_basic).and_return(user)
      end

      it 'sets current_user from HTTP Basic' do
        get :index
        expect(response).to have_http_status(:ok)
        expect(controller.instance_variable_get(:@current_user)).to eq(user)
      end
    end

    context 'when all authentication methods fail' do
      before do
        allow(controller).to receive(:authenticate_with_token).and_return(nil)
        allow(controller).to receive(:authenticate_with_api_key).and_return(nil)
        allow(controller).to receive(:authenticate_with_http_basic).and_return(nil)
      end

      it 'returns 401 Unauthorized' do
        get :index
        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)['error']).to eq('unauthorized')
      end
    end
  end

  describe '#authenticate_with_api_key' do
    before do
      api_key # Ensure the API key is created
      request.headers['X-API-Key'] = 'valid-api-key-token'
    end

    it 'finds a valid API key and returns its user' do
      allow(ApiKey).to receive(:valid_for_use).and_return(ApiKey)
      allow(ApiKey).to receive(:find_by).with(token: 'valid-api-key-token').and_return(api_key)
      allow(api_key).to receive(:record_usage!)

      result = controller.send(:authenticate_with_api_key)

      expect(result).to eq(user)
      expect(controller.instance_variable_get(:@current_api_key)).to eq(api_key)
      expect(api_key).to have_received(:record_usage!)
    end

    it 'returns nil if API key is not found' do
      allow(ApiKey).to receive(:valid_for_use).and_return(ApiKey)
      allow(ApiKey).to receive(:find_by).with(token: 'valid-api-key-token').and_return(nil)

      result = controller.send(:authenticate_with_api_key)

      expect(result).to be_nil
      expect(controller.instance_variable_get(:@current_api_key)).to be_nil
    end

    it 'returns nil if X-API-Key header is not present' do
      request.headers['X-API-Key'] = nil

      result = controller.send(:authenticate_with_api_key)

      expect(result).to be_nil
    end
  end

  describe '#authenticate_with_http_basic' do
    context 'with regular user credentials' do
      before do
        # Mock the HTTP Basic authentication
        allow(ActionController::HttpAuthentication::Basic).to receive(:authenticate).and_yield(user.email, 'password')
        allow(User).to receive(:find_by).with(email: user.email).and_return(user)
        allow(user).to receive(:valid_password?).with('password').and_return(true)
        allow(user).to receive(:agent?).and_return(false)
        allow(user).to receive(:registered?).and_return(true)
      end

      it 'authenticates a regular user with valid credentials' do
        result = controller.send(:authenticate_with_http_basic)

        expect(result).to eq(user)
      end
    end

    context 'with agent user credentials' do
      before do
        # Mock the HTTP Basic authentication for agent
        allow(ActionController::HttpAuthentication::Basic).to receive(:authenticate).and_yield(agent_user.email, 'password')
        allow(User).to receive(:find_by).with(email: agent_user.email).and_return(agent_user)
        allow(agent_user).to receive(:valid_password?).with('password').and_return(true)
        allow(agent_user).to receive(:agent?).and_return(true)

        # Mock the API key for agent
        request.headers['X-API-Key'] = 'agent-api-key-token'
        allow(agent_user).to receive_message_chain(:api_keys, :valid_for_use, :find_by).and_return(agent_api_key)
        allow(agent_api_key).to receive(:record_usage!)
      end

      it 'authenticates an agent with valid credentials and API key' do
        result = controller.send(:authenticate_with_http_basic)

        expect(result).to eq(agent_user)
        expect(controller.instance_variable_get(:@current_api_key)).to eq(agent_api_key)
        expect(agent_api_key).to have_received(:record_usage!)
      end

      it 'fails to authenticate an agent without an API key' do
        request.headers['X-API-Key'] = nil

        result = controller.send(:authenticate_with_http_basic)

        expect(result).to be_nil
      end

      it 'fails to authenticate an agent with invalid API key' do
        allow(agent_user).to receive_message_chain(:api_keys, :valid_for_use, :find_by).and_return(nil)

        result = controller.send(:authenticate_with_http_basic)

        expect(result).to be_nil
      end
    end

    context 'with invalid credentials' do
      before do
        # Mock the HTTP Basic authentication with invalid credentials
        allow(ActionController::HttpAuthentication::Basic).to receive(:authenticate).and_yield(user.email, 'wrong_password')
        allow(User).to receive(:find_by).with(email: user.email).and_return(user)
        allow(user).to receive(:valid_password?).with('wrong_password').and_return(false)
      end

      it 'fails to authenticate with invalid password' do
        result = controller.send(:authenticate_with_http_basic)

        expect(result).to be_nil
      end
    end

    context 'with nonexistent user' do
      before do
        # Mock the HTTP Basic authentication with nonexistent user
        allow(ActionController::HttpAuthentication::Basic).to receive(:authenticate).and_yield('nonexistent@example.com', 'password')
        allow(User).to receive(:find_by).with(email: 'nonexistent@example.com').and_return(nil)
      end

      it 'fails to authenticate with nonexistent user' do
        result = controller.send(:authenticate_with_http_basic)

        expect(result).to be_nil
      end
    end

    context 'when HTTP Basic authentication is not provided' do
      before do
        allow(ActionController::HttpAuthentication::Basic).to receive(:authenticate).and_return(nil)
      end

      it 'returns nil if no credentials are provided' do
        result = controller.send(:authenticate_with_http_basic)

        expect(result).to be_nil
      end
    end
  end

  describe '#token' do
    it 'extracts token from Authorization header' do
      request.headers['Authorization'] = 'Bearer jwt-token-value'

      expect(controller.send(:token)).to eq('jwt-token-value')
    end

    it 'returns nil if Authorization header is missing' do
      request.headers['Authorization'] = nil

      expect(controller.send(:token)).to be_nil
    end

    it 'returns nil if Authorization header has invalid format' do
      request.headers['Authorization'] = 'InvalidFormat'

      expect(controller.send(:token)).to be_nil
    end
  end
end
