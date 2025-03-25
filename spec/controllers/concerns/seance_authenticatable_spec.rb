require 'rails_helper'

# Test controller for testing the concern
class TestSeanceController < ApplicationController
  include SeanceAuthenticatable

  def protected_action
    render json: { client_id: current_client_id, status: "success" }
  end
end

# Configure routes for testing
Rails.application.routes.draw do
  get 'test_seance/protected', to: 'test_seance#protected_action'
end

RSpec.describe SeanceAuthenticatable, type: :controller do
  controller(TestSeanceController) do
  end

  let(:valid_token) { "valid.token.123" }
  let(:invalid_token) { "invalid.token.123" }
  let(:client_id) { "client-123" }
  let(:token_service) { instance_double(SeanceTokenService) }

  before do
    routes.draw { get 'protected_action' => 'test_seance#protected_action' }

    # Stub the token service
    allow(SeanceTokenService).to receive(:new).and_return(token_service)

    # Define the behavior for valid token
    allow(token_service).to receive(:validate_token).with(valid_token).and_return({
      valid: true,
      client_id: client_id
    })

    # Define the behavior for invalid token
    allow(token_service).to receive(:validate_token).with(invalid_token).and_return({
      valid: false,
      error: "Invalid token"
    })
  end

  describe "#authenticate_seance!" do
    context "with a valid token" do
      it "allows access to the protected action" do
        request.headers["Authorization"] = "Bearer #{valid_token}"

        get :protected_action

        expect(response).to have_http_status(:success)
        expect(JSON.parse(response.body)['client_id']).to eq(client_id)
        expect(JSON.parse(response.body)['status']).to eq("success")
      end

      it "sets the current_client_id" do
        request.headers["Authorization"] = "Bearer #{valid_token}"

        get :protected_action

        expect(controller.instance_variable_get(:@current_client_id)).to eq(client_id)
      end
    end

    context "with an invalid token" do
      it "returns unauthorized with error message" do
        request.headers["Authorization"] = "Bearer #{invalid_token}"

        get :protected_action

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)['error']).to eq("Invalid token")
      end
    end

    context "without a token" do
      it "returns unauthorized when no token is provided" do
        get :protected_action

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)['error']).to eq("token is required")
      end

      it "returns unauthorized when authorization header is empty" do
        request.headers["Authorization"] = ""

        get :protected_action

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)['error']).to eq("token is required")
      end
    end
  end

  describe "#extract_token_from_header" do
    it "extracts token from bearer authorization header" do
      request.headers["Authorization"] = "Bearer token123"

      token = controller.send(:extract_token_from_header)

      expect(token).to eq("token123")
    end

    it "extracts token from alternative format header" do
      request.headers["Authorization"] = "Token token456"

      token = controller.send(:extract_token_from_header)

      expect(token).to eq("token456")
    end

    it "returns nil when authorization header is missing" do
      token = controller.send(:extract_token_from_header)

      expect(token).to be_nil
    end
  end

  describe "#token_service" do
    it "initializes a new SeanceTokenService" do
      expect(SeanceTokenService).to receive(:new).once

      controller.send(:token_service)
    end

    it "memoizes the token service" do
      # Call twice to check memoization
      first_call = controller.send(:token_service)
      second_call = controller.send(:token_service)

      expect(first_call).to eq(second_call)
      expect(SeanceTokenService).to have_received(:new).once
    end
  end

  describe "#current_client_id" do
    it "returns the value of @current_client_id" do
      controller.instance_variable_set(:@current_client_id, client_id)

      expect(controller.send(:current_client_id)).to eq(client_id)
    end
  end
end
