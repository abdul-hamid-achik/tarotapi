require 'rails_helper'

# Create a test controller that includes the concern
class TestSeanceController < ApplicationController
  include SeanceAuthenticatable

  def index
    render json: { client_id: current_client_id, authenticated: true }
  end
end

RSpec.describe SeanceAuthenticatable, type: :controller do
  # Use the test controller for our tests
  controller(TestSeanceController) do
  end

  let(:client_id) { "11111111-1111-4111-a111-111111111111" }
  let(:token_service) { instance_double("SeanceTokenService") }
  let(:valid_token) { "valid-seance-token" }

  before do
    allow(controller).to receive(:token_service).and_return(token_service)
  end

  describe '#authenticate_seance!' do
    context 'with valid token' do
      before do
        request.headers["Authorization"] = "Bearer #{valid_token}"
        allow(token_service).to receive(:validate_token).with(valid_token).and_return({
          valid: true,
          client_id: client_id
        })
      end

      it 'sets current_client_id and allows access' do
        get :index

        expect(response).to have_http_status(:ok)
        expect(controller.instance_variable_get(:@current_client_id)).to eq(client_id)
        expect(JSON.parse(response.body)['client_id']).to eq(client_id)
      end
    end

    context 'with missing token' do
      it 'returns 401 Unauthorized with appropriate message' do
        get :index

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)['error']).to eq('token is required')
      end
    end

    context 'with invalid token' do
      before do
        request.headers["Authorization"] = "Bearer invalid-token"
        allow(token_service).to receive(:validate_token).with('invalid-token').and_return({
          valid: false,
          error: "token expired"
        })
      end

      it 'returns 401 Unauthorized with error message from token service' do
        get :index

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)['error']).to eq('token expired')
      end
    end
  end

  describe '#extract_token_from_header' do
    it 'extracts token from Authorization header' do
      request.headers["Authorization"] = "Bearer #{valid_token}"

      expect(controller.send(:extract_token_from_header)).to eq(valid_token)
    end

    it 'returns nil if Authorization header is missing' do
      request.headers["Authorization"] = nil

      expect(controller.send(:extract_token_from_header)).to be_nil
    end

    it 'extracts token from malformed Authorization header' do
      request.headers["Authorization"] = valid_token

      expect(controller.send(:extract_token_from_header)).to eq(valid_token)
    end
  end

  describe '#token_service' do
    it 'returns an instance of SeanceTokenService' do
      # Reset the stub to test the real method
      allow(controller).to receive(:token_service).and_call_original
      allow(SeanceTokenService).to receive(:new).and_return(token_service)

      expect(controller.send(:token_service)).to eq(token_service)
      # Test memoization
      expect(controller.send(:token_service)).to eq(token_service)
      expect(SeanceTokenService).to have_received(:new).once
    end
  end

  describe '#current_client_id' do
    it 'returns the current client ID' do
      controller.instance_variable_set(:@current_client_id, client_id)

      expect(controller.send(:current_client_id)).to eq(client_id)
    end
  end

  describe '#unauthorized_error' do
    it 'renders JSON error with unauthorized status' do
      expect(controller).to receive(:render).with(
        json: { error: 'test error' },
        status: :unauthorized
      )

      controller.send(:unauthorized_error, 'test error')
    end
  end
end
