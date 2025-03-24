require 'rails_helper'

RSpec.describe Api::V1::OauthController, type: :request do
  let(:client) { create(:api_client) }
  let(:user) { create(:user) }

  describe 'GET /api/v1/oauth/authorize' do
    let(:valid_params) do
      {
        client_id: client.client_id,
        client_secret: client.client_secret,
        redirect_uri: 'https://example.com/callback',
        response_type: 'code',
        scope: 'read',
        state: 'random_state'
      }
    end

    context 'when client credentials are valid' do
      before do
        allow_any_instance_of(Api::V1::OauthController).to receive(:validate_client).and_return(true)
      end

      context 'when user is not logged in' do
        before do
          allow_any_instance_of(Api::V1::OauthController).to receive(:current_user).and_return(nil)
        end

        it 'returns a redirect to login page' do
          get '/api/v1/oauth/authorize', params: valid_params

          expect(response).to have_http_status(:ok)
          body = JSON.parse(response.body)
          expect(body).to have_key('redirect_to')
          expect(body).to have_key('oauth_params')
          expect(body['oauth_params']['client_id']).to eq(client.client_id)
        end
      end

      context 'when user is logged in' do
        before do
          allow_any_instance_of(Api::V1::OauthController).to receive(:current_user).and_return(user)
          allow(SecureRandom).to receive(:hex).and_return('random_code')
        end

        it 'creates an authorization and returns code' do
          expect {
            get '/api/v1/oauth/authorize', params: valid_params
          }.to change(Authorization, :count).by(1)

          expect(response).to have_http_status(:ok)
          body = JSON.parse(response.body)
          expect(body).to have_key('code')
          expect(body['state']).to eq('random_state')

          authorization = Authorization.last
          expect(authorization.user).to eq(user)
          expect(authorization.client_id).to eq(client.client_id)
          expect(authorization.code).to eq('random_code')
          expect(authorization.scope).to eq('read')
        end
      end

      context 'when request parameters are invalid' do
        it 'returns bad request for missing response_type' do
          get '/api/v1/oauth/authorize', params: valid_params.except(:response_type)

          expect(response).to have_http_status(:bad_request)
          body = JSON.parse(response.body)
          expect(body['error']).to eq('invalid_request')
        end

        it 'returns bad request for missing client_id' do
          get '/api/v1/oauth/authorize', params: valid_params.except(:client_id)

          expect(response).to have_http_status(:bad_request)
          body = JSON.parse(response.body)
          expect(body['error']).to eq('invalid_request')
        end

        it 'returns bad request for missing redirect_uri' do
          get '/api/v1/oauth/authorize', params: valid_params.except(:redirect_uri)

          expect(response).to have_http_status(:bad_request)
          body = JSON.parse(response.body)
          expect(body['error']).to eq('invalid_request')
        end

        it 'returns bad request for missing scope' do
          get '/api/v1/oauth/authorize', params: valid_params.except(:scope)

          expect(response).to have_http_status(:bad_request)
          body = JSON.parse(response.body)
          expect(body['error']).to eq('invalid_request')
        end
      end
    end

    context 'when client credentials are invalid' do
      before do
        allow_any_instance_of(Api::V1::OauthController).to receive(:validate_client).and_raise(StandardError)
        allow_any_instance_of(Api::V1::OauthController).to receive(:render).with(json: { error: "invalid_client" }, status: :unauthorized).and_return(nil)
      end

      it 'returns unauthorized error' do
        get '/api/v1/oauth/authorize', params: valid_params.merge(client_id: 'invalid')

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/oauth/token' do
    let(:authorization) { create(:authorization, user: user, client_id: client.client_id, code: 'valid_code', scope: 'read') }
    let(:valid_params) do
      {
        client_id: client.client_id,
        client_secret: client.client_secret,
        grant_type: 'authorization_code',
        code: authorization.code
      }
    end

    context 'when client credentials are valid' do
      before do
        allow_any_instance_of(Api::V1::OauthController).to receive(:validate_client).and_return(true)
      end

      context 'when authorization code is valid' do
        let(:access_token) { create(:access_token, user: user, client_id: client.client_id) }

        before do
          allow_any_instance_of(Authorization).to receive(:generate_access_token!).and_return(access_token)
        end

        it 'returns an access token' do
          post '/api/v1/oauth/token', params: valid_params

          expect(response).to have_http_status(:ok)
          body = JSON.parse(response.body)
          expect(body['access_token']).to eq(access_token.token)
          expect(body['token_type']).to eq('Bearer')
          expect(body['expires_in']).to eq(access_token.expires_in)
          expect(body['refresh_token']).to eq(access_token.refresh_token)
          expect(body['scope']).to eq(access_token.scope)
        end
      end

      context 'when authorization code is invalid' do
        it 'returns bad request error' do
          post '/api/v1/oauth/token', params: valid_params.merge(code: 'invalid_code')

          expect(response).to have_http_status(:bad_request)
          body = JSON.parse(response.body)
          expect(body['error']).to eq('invalid_grant')
        end
      end

      context 'when authorization code is expired' do
        before do
          authorization.update(expires_at: 1.day.ago)
        end

        it 'returns bad request error' do
          post '/api/v1/oauth/token', params: valid_params

          expect(response).to have_http_status(:bad_request)
          body = JSON.parse(response.body)
          expect(body['error']).to eq('invalid_grant')
        end
      end

      context 'when grant type is invalid' do
        it 'returns bad request error' do
          post '/api/v1/oauth/token', params: valid_params.merge(grant_type: 'invalid')

          expect(response).to have_http_status(:bad_request)
          body = JSON.parse(response.body)
          expect(body['error']).to eq('unsupported_grant_type')
        end
      end
    end

    context 'when client credentials are invalid' do
      before do
        allow_any_instance_of(Api::V1::OauthController).to receive(:validate_client).and_raise(StandardError)
        allow_any_instance_of(Api::V1::OauthController).to receive(:render).with(json: { error: "invalid_client" }, status: :unauthorized).and_return(nil)
      end

      it 'returns unauthorized error' do
        post '/api/v1/oauth/token', params: valid_params.merge(client_id: 'invalid')

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe '#validate_client' do
    let(:controller) { Api::V1::OauthController.new }

    before do
      allow(controller).to receive(:params).and_return(
        client_id: client.client_id,
        client_secret: client.client_secret
      )
      allow(controller).to receive(:render)
    end

    context 'when client exists and secret is valid' do
      it 'returns true' do
        expect(ApiClient).to receive(:find_by).with(client_id: client.client_id).and_return(client)
        expect(client).to receive(:valid_secret?).with(client.client_secret).and_return(true)

        expect(controller.send(:validate_client)).to be_truthy
      end
    end

    context 'when client does not exist' do
      it 'renders error and returns nil' do
        expect(ApiClient).to receive(:find_by).with(client_id: client.client_id).and_return(nil)
        expect(controller).to receive(:render).with(json: { error: "invalid_client" }, status: :unauthorized)

        expect(controller.send(:validate_client)).to be_nil
      end
    end

    context 'when client secret is invalid' do
      it 'renders error and returns nil' do
        expect(ApiClient).to receive(:find_by).with(client_id: client.client_id).and_return(client)
        expect(client).to receive(:valid_secret?).with(client.client_secret).and_return(false)
        expect(controller).to receive(:render).with(json: { error: "invalid_client" }, status: :unauthorized)

        expect(controller.send(:validate_client)).to be_nil
      end
    end
  end

  describe '#valid_authorization_params?' do
    let(:controller) { Api::V1::OauthController.new }

    context 'when all required parameters are present' do
      it 'returns true' do
        allow(controller).to receive(:params).and_return(
          response_type: 'code',
          client_id: 'client123',
          redirect_uri: 'https://example.com/callback',
          scope: 'read'
        )

        expect(controller.send(:valid_authorization_params?)).to be true
      end
    end

    context 'when response_type is not code' do
      it 'returns false' do
        allow(controller).to receive(:params).and_return(
          response_type: 'token',
          client_id: 'client123',
          redirect_uri: 'https://example.com/callback',
          scope: 'read'
        )

        expect(controller.send(:valid_authorization_params?)).to be false
      end
    end

    context 'when any required parameter is missing' do
      it 'returns false when client_id is missing' do
        allow(controller).to receive(:params).and_return(
          response_type: 'code',
          redirect_uri: 'https://example.com/callback',
          scope: 'read'
        )

        expect(controller.send(:valid_authorization_params?)).to be false
      end

      it 'returns false when redirect_uri is missing' do
        allow(controller).to receive(:params).and_return(
          response_type: 'code',
          client_id: 'client123',
          scope: 'read'
        )

        expect(controller.send(:valid_authorization_params?)).to be false
      end

      it 'returns false when scope is missing' do
        allow(controller).to receive(:params).and_return(
          response_type: 'code',
          client_id: 'client123',
          redirect_uri: 'https://example.com/callback'
        )

        expect(controller.send(:valid_authorization_params?)).to be false
      end
    end
  end
end
