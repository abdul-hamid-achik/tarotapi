require 'rails_helper'

RSpec.describe 'api/v1/seance', type: :request do
  describe 'post /api/v1/seance' do
    let(:client_id) { SecureRandom.uuid }
    let(:valid_params) { { client_id: client_id } }

    context 'with valid client_id' do
      it 'returns a session token' do
        post '/api/v1/seance', params: valid_params

        expect(response).to have_http_status(:created)
        expect(json_response['token']).to be_present
        expect(json_response['expires_at']).to be_present
      end

      it 'returns the same token for the same client_id within expiration' do
        post '/api/v1/seance', params: valid_params
        first_token = json_response['token']

        post '/api/v1/seance', params: valid_params
        expect(json_response['token']).to eq(first_token)
      end
    end

    context 'with invalid params' do
      it 'returns error for missing client_id' do
        post '/api/v1/seance', params: {}

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['error']).to include('client_id is required')
      end

      it 'returns error for invalid client_id format' do
        post '/api/v1/seance', params: { client_id: 'invalid' }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['error']).to include('invalid client_id format')
      end
    end
  end

  describe 'get /api/v1/seance/validate' do
    let(:client_id) { SecureRandom.uuid }
    let(:valid_token) do
      post '/api/v1/seance', params: { client_id: client_id }
      json_response['token']
    end

    it 'validates a valid token' do
      get '/api/v1/seance/validate', headers: { 'authorization' => "bearer #{valid_token}" }

      expect(response).to have_http_status(:ok)
      expect(json_response['valid']).to be true
      expect(json_response['client_id']).to eq(client_id)
    end

    it 'rejects an invalid token' do
      get '/api/v1/seance/validate', headers: { 'authorization' => 'bearer invalid_token' }

      expect(response).to have_http_status(:unauthorized)
      expect(json_response['error']).to include('invalid token')
    end

    it 'rejects a missing token' do
      get '/api/v1/seance/validate'

      expect(response).to have_http_status(:unauthorized)
      expect(json_response['error']).to include('token is required')
    end
  end

  private

  def json_response
    JSON.parse(response.body)
  end
end
