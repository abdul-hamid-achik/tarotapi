module Api
  module V1
    class SeanceController < ApplicationController
      # Skip authentication for seance endpoints
      skip_before_action :authenticate_request

      # POST /api/v1/seance
      def create
        client_id = params[:client_id]

        begin
          token_service = SeanceTokenService.new
          token_data = token_service.generate_token(client_id)

          render json: { token: token_data[:token], expires_at: token_data[:expires_at] }, status: :created
        rescue ArgumentError => e
          render json: { error: e.message }, status: :unprocessable_entity
        end
      end

      # GET /api/v1/seance/validate
      def validate
        token = request.headers["X-Seance-Token"] || params[:token]

        unless token.present?
          return render json: { valid: false, error: "missing token" }, status: :unauthorized
        end

        token_service = SeanceTokenService.new
        result = token_service.validate_token(token)

        if result[:valid]
          render json: { valid: true, client_id: result[:client_id] }
        else
          render json: { valid: false, error: result[:error] }, status: :unauthorized
        end
      end
    end
  end
end
