require 'rails_helper'

RSpec.describe "Api::V1::Oauth", type: :request do
  let(:headers) { { "Accept" => "application/json" } }
  let(:user) { create(:user) }
  let(:api_client) { create(:api_client) }

  # Helper method to get authorization from previous authenticate request
  let(:auth_headers) do
    allow_any_instance_of(Api::V1::OauthController).to receive(:current_user).and_return(user)
    headers
  end

  describe "GET /api/v1/oauth/authorize" do
    context "with valid parameters" do
      it "returns an authorization code when user is logged in" do
        allow_any_instance_of(Api::V1::OauthController).to receive(:current_user).and_return(user)

        params = {
          client_id: api_client.client_id,
          redirect_uri: api_client.redirect_uri,
          response_type: "code",
          scope: "read write",
          state: "random_state"
        }

        get "/api/v1/oauth/authorize", params: params, headers: headers

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response).to include("code", "state")
        expect(json_response["state"]).to eq("random_state")

        # Verify that an authorization was created
        authorization = Authorization.last
        expect(authorization).not_to be_nil
        expect(authorization.user).to eq(user)
        expect(authorization.client_id).to eq(api_client.client_id)
        expect(authorization.scope).to eq("read write")
      end

      it "redirects to login when user is not logged in" do
        allow_any_instance_of(Api::V1::OauthController).to receive(:current_user).and_return(nil)

        params = {
          client_id: api_client.client_id,
          redirect_uri: api_client.redirect_uri,
          response_type: "code",
          scope: "read",
          state: "random_state"
        }

        get "/api/v1/oauth/authorize", params: params, headers: headers

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response).to include("redirect_to", "oauth_params")
        expect(json_response["redirect_to"]).to eq("/login")
      end
    end

    context "with invalid parameters" do
      it "returns error for missing client_id" do
        params = {
          redirect_uri: "https://example.com/callback",
          response_type: "code",
          scope: "read"
        }

        get "/api/v1/oauth/authorize", params: params, headers: headers

        expect(response).to have_http_status(:bad_request)
        json_response = JSON.parse(response.body)
        expect(json_response["error"]).to eq("invalid_request")
      end

      it "returns error for missing response_type" do
        params = {
          client_id: api_client.client_id,
          redirect_uri: api_client.redirect_uri,
          scope: "read"
        }

        get "/api/v1/oauth/authorize", params: params, headers: headers

        expect(response).to have_http_status(:bad_request)
        json_response = JSON.parse(response.body)
        expect(json_response["error"]).to eq("invalid_request")
      end

      it "returns error for invalid response_type" do
        params = {
          client_id: api_client.client_id,
          redirect_uri: api_client.redirect_uri,
          response_type: "invalid",
          scope: "read"
        }

        get "/api/v1/oauth/authorize", params: params, headers: headers

        expect(response).to have_http_status(:bad_request)
        json_response = JSON.parse(response.body)
        expect(json_response["error"]).to eq("invalid_request")
      end

      it "returns error for missing scope" do
        params = {
          client_id: api_client.client_id,
          redirect_uri: api_client.redirect_uri,
          response_type: "code"
        }

        get "/api/v1/oauth/authorize", params: params, headers: headers

        expect(response).to have_http_status(:bad_request)
        json_response = JSON.parse(response.body)
        expect(json_response["error"]).to eq("invalid_request")
      end
    end

    context "in test environment" do
      before do
        allow(Rails.env).to receive(:test?).and_return(true)
      end

      it "returns test authorization code" do
        allow_any_instance_of(Api::V1::OauthController).to receive(:current_user).and_return(user)

        params = {
          client_id: "test",
          redirect_uri: "https://example.com/callback",
          response_type: "code",
          scope: "read",
          state: "test_state"
        }

        get "/api/v1/oauth/authorize", params: params, headers: headers

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response["code"]).to eq("test_auth_code")
        expect(json_response["state"]).to eq("test_state")
      end
    end
  end

  describe "POST /api/v1/oauth/token" do
    let!(:authorization) { create(:authorization, user: user, client_id: api_client.client_id) }

    context "with valid authorization code" do
      it "returns an access token" do
        params = {
          client_id: api_client.client_id,
          client_secret: api_client.client_secret,
          grant_type: "authorization_code",
          code: authorization.code,
          redirect_uri: api_client.redirect_uri
        }

        post "/api/v1/oauth/token", params: params, headers: headers

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response).to include(
          "access_token",
          "token_type",
          "expires_in",
          "refresh_token",
          "scope"
        )
        expect(json_response["token_type"]).to eq("Bearer")

        # Verify that an access token was created
        access_token = AccessToken.last
        expect(access_token).not_to be_nil
        expect(access_token.user).to eq(user)
      end
    end

    context "with invalid authorization code" do
      it "returns error for invalid code" do
        params = {
          client_id: api_client.client_id,
          client_secret: api_client.client_secret,
          grant_type: "authorization_code",
          code: "invalid_code",
          redirect_uri: api_client.redirect_uri
        }

        post "/api/v1/oauth/token", params: params, headers: headers

        expect(response).to have_http_status(:bad_request)
        json_response = JSON.parse(response.body)
        expect(json_response["error"]).to eq("invalid_grant")
      end

      it "returns error for expired code" do
        # Create expired authorization code
        expired_auth = create(:authorization,
          user: user,
          client_id: api_client.client_id,
          expires_at: 1.hour.ago
        )

        params = {
          client_id: api_client.client_id,
          client_secret: api_client.client_secret,
          grant_type: "authorization_code",
          code: expired_auth.code,
          redirect_uri: api_client.redirect_uri
        }

        post "/api/v1/oauth/token", params: params, headers: headers

        expect(response).to have_http_status(:bad_request)
        json_response = JSON.parse(response.body)
        expect(json_response["error"]).to eq("invalid_grant")
      end
    end

    context "with invalid client credentials" do
      it "returns error for invalid client_id" do
        params = {
          client_id: "invalid_client_id",
          client_secret: api_client.client_secret,
          grant_type: "authorization_code",
          code: authorization.code,
          redirect_uri: api_client.redirect_uri
        }

        post "/api/v1/oauth/token", params: params, headers: headers

        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)
        expect(json_response["error"]).to eq("invalid_client")
      end

      it "returns error for invalid client_secret" do
        params = {
          client_id: api_client.client_id,
          client_secret: "invalid_secret",
          grant_type: "authorization_code",
          code: authorization.code,
          redirect_uri: api_client.redirect_uri
        }

        post "/api/v1/oauth/token", params: params, headers: headers

        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)
        expect(json_response["error"]).to eq("invalid_client")
      end
    end

    context "with invalid grant type" do
      it "returns error for unsupported grant type" do
        params = {
          client_id: api_client.client_id,
          client_secret: api_client.client_secret,
          grant_type: "invalid_grant_type",
          code: authorization.code,
          redirect_uri: api_client.redirect_uri
        }

        post "/api/v1/oauth/token", params: params, headers: headers

        expect(response).to have_http_status(:bad_request)
        json_response = JSON.parse(response.body)
        expect(json_response["error"]).to eq("unsupported_grant_type")
      end
    end

    context "in test environment" do
      before do
        allow(Rails.env).to receive(:test?).and_return(true)
      end

      it "returns test access token" do
        params = {
          client_id: "test",
          client_secret: "test_secret",
          grant_type: "authorization_code",
          code: "test_code",
          redirect_uri: "https://example.com/callback"
        }

        post "/api/v1/oauth/token", params: params, headers: headers

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        expect(json_response["access_token"]).to eq("test_access_token")
        expect(json_response["refresh_token"]).to eq("test_refresh_token")
        expect(json_response["token_type"]).to eq("Bearer")
        expect(json_response["expires_in"]).to eq(3600)
      end
    end
  end
end
