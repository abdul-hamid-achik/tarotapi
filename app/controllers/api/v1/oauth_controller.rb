module Api
  module V1
    class OauthController < ApplicationController
      skip_before_action :authenticate_user!, only: [:authorize, :token]
      before_action :validate_client, only: [:authorize, :token]

      def authorize
        # Validate request parameters
        unless valid_authorization_params?
          return render json: { error: 'invalid_request' }, status: :bad_request
        end

        # Store authorization request in session
        session[:oauth] = {
          client_id: params[:client_id],
          redirect_uri: params[:redirect_uri],
          scope: params[:scope],
          state: params[:state],
          response_type: params[:response_type]
        }

        # If user is not logged in, redirect to login
        unless current_user
          return render json: { 
            redirect_to: new_user_session_path,
            oauth_params: session[:oauth]
          }
        end

        # Generate authorization code
        code = SecureRandom.hex(32)
        authorization = Authorization.create!(
          user: current_user,
          client_id: params[:client_id],
          code: code,
          scope: params[:scope],
          expires_at: 10.minutes.from_now
        )

        # Return authorization code
        render json: {
          code: authorization.code,
          state: params[:state]
        }
      end

      def token
        # Validate grant type
        unless params[:grant_type] == 'authorization_code'
          return render json: { error: 'unsupported_grant_type' }, status: :bad_request
        end

        # Find and validate authorization code
        authorization = Authorization.find_by(code: params[:code])
        if authorization.nil? || authorization.expired?
          return render json: { error: 'invalid_grant' }, status: :bad_request
        end

        # Generate access token
        access_token = authorization.generate_access_token!

        # Return access token
        render json: {
          access_token: access_token.token,
          token_type: 'Bearer',
          expires_in: access_token.expires_in,
          refresh_token: access_token.refresh_token,
          scope: access_token.scope
        }
      end

      private

      def validate_client
        @client = ApiClient.find_by(client_id: params[:client_id])
        unless @client && @client.valid_secret?(params[:client_secret])
          render json: { error: 'invalid_client' }, status: :unauthorized
        end
      end

      def valid_authorization_params?
        params[:response_type] == 'code' &&
          params[:client_id].present? &&
          params[:redirect_uri].present? &&
          params[:scope].present?
      end
    end
  end
end 