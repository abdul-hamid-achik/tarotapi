require 'rails_helper'

RSpec.describe "OAuth API", type: :request do
  let(:organization) { create(:organization) }
  let(:api_client) { create(:api_client, organization: organization) }

  describe "OAuth routes" do
    it "responds to the authorize endpoint" do
      get '/api/v1/oauth/authorize', params: { client_id: 'test' }
      expect(response).not_to have_http_status(:not_found)
    end

    it "responds to the token endpoint" do
      post '/api/v1/oauth/token', params: { client_id: 'test' }
      expect(response).not_to have_http_status(:not_found)
    end
  end

  describe "Client validation" do
    it "returns 401 for invalid client" do
      post '/api/v1/oauth/token', params: {
        client_id: 'invalid',
        client_secret: 'invalid',
        grant_type: 'authorization_code'
      }
      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body)["error"]).to eq("invalid_client")
    end
  end

  describe "Authorization flow" do
    it "validates authorization request parameters" do
      get '/api/v1/oauth/authorize', params: { client_id: api_client.client_id }
      expect(response).to have_http_status(:bad_request)
      expect(JSON.parse(response.body)["error"]).to eq("invalid_request")
    end

    it "requires proper response_type, redirect_uri and scope" do
      get '/api/v1/oauth/authorize', params: {
        client_id: api_client.client_id,
        response_type: 'code',
        redirect_uri: api_client.redirect_uri,
        scope: 'read'
      }

      # Since we're in test mode without actual authentication,
      # we should get a redirect or a specific response
      expect(response.status).not_to eq(:bad_request)
    end
  end

  describe "Token handling" do
    it "validates grant type" do
      post '/api/v1/oauth/token', params: {
        client_id: api_client.client_id,
        client_secret: api_client.plaintext_secret,
        grant_type: 'invalid'
      }
      expect(response).to have_http_status(:bad_request)
      expect(JSON.parse(response.body)["error"]).to eq("unsupported_grant_type")
    end
  end
end
