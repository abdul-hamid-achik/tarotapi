require 'rails_helper'

RSpec.describe Api::V1::SeanceController, type: :request do
  let(:valid_client_id) { "11111111-1111-4111-a111-111111111111" }
  let(:invalid_client_id) { "invalid-id" }
  let(:valid_token) { "valid_token_123" }
  let(:mock_token_service) { instance_double(SeanceTokenService) }
  let(:token_data) { { token: valid_token, expires_at: 1.hour.from_now } }
  let(:valid_token_response) { { valid: true, client_id: valid_client_id } }
  let(:invalid_token_response) { { valid: false, error: "token expired" } }

  before do
    allow(SeanceTokenService).to receive(:new).and_return(mock_token_service)
  end

  describe "POST /api/v1/seance" do
    context "with valid client_id" do
      before do
        allow(mock_token_service).to receive(:generate_token).with(valid_client_id).and_return(token_data)
      end

      it "creates a new token and returns 201" do
        post "/api/v1/seance", params: { client_id: valid_client_id }

        expect(response).to have_http_status(:created)
        expect(JSON.parse(response.body)).to include(
          "token" => valid_token,
          "expires_at" => token_data[:expires_at].as_json
        )
      end
    end

    context "with invalid client_id" do
      before do
        allow(mock_token_service).to receive(:generate_token).with(invalid_client_id)
          .and_raise(ArgumentError.new("invalid client_id format"))
      end

      it "returns 422 unprocessable entity" do
        post "/api/v1/seance", params: { client_id: invalid_client_id }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)).to include(
          "error" => "invalid client_id format"
        )
      end
    end
  end

  describe "GET /api/v1/seance/validate" do
    context "when token is missing" do
      it "returns 401 unauthorized" do
        get "/api/v1/seance/validate"

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)).to include(
          "valid" => false,
          "error" => "missing token"
        )
      end
    end

    context "when token is present in params" do
      context "with valid token" do
        before do
          allow(mock_token_service).to receive(:validate_token).with(valid_token).and_return(valid_token_response)
        end

        it "returns valid status with client_id" do
          get "/api/v1/seance/validate", params: { token: valid_token }

          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)).to include(
            "valid" => true,
            "client_id" => valid_client_id
          )
        end
      end

      context "with invalid token" do
        before do
          allow(mock_token_service).to receive(:validate_token).with("invalid_token").and_return(invalid_token_response)
        end

        it "returns invalid status with error" do
          get "/api/v1/seance/validate", params: { token: "invalid_token" }

          expect(response).to have_http_status(:unauthorized)
          expect(JSON.parse(response.body)).to include(
            "valid" => false,
            "error" => "token expired"
          )
        end
      end
    end

    context "when token is present in headers" do
      context "with valid token" do
        before do
          allow(mock_token_service).to receive(:validate_token).with(valid_token).and_return(valid_token_response)
        end

        it "returns valid status with client_id" do
          get "/api/v1/seance/validate", headers: { "X-Seance-Token" => valid_token }

          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)).to include(
            "valid" => true,
            "client_id" => valid_client_id
          )
        end
      end

      context "with invalid token" do
        before do
          allow(mock_token_service).to receive(:validate_token).with("invalid_token").and_return(invalid_token_response)
        end

        it "returns invalid status with error" do
          get "/api/v1/seance/validate", headers: { "X-Seance-Token" => "invalid_token" }

          expect(response).to have_http_status(:unauthorized)
          expect(JSON.parse(response.body)).to include(
            "valid" => false,
            "error" => "token expired"
          )
        end
      end
    end

    context "when token is present in both headers and params" do
      before do
        # Headers should take precedence over params
        allow(mock_token_service).to receive(:validate_token).with(valid_token).and_return(valid_token_response)
      end

      it "uses the token from headers" do
        get "/api/v1/seance/validate",
            params: { token: "param_token" },
            headers: { "X-Seance-Token" => valid_token }

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to include(
          "valid" => true,
          "client_id" => valid_client_id
        )
      end
    end
  end
end
