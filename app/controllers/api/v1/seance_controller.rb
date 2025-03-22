module Api
  module V1
    class SeanceController < ApplicationController
      def create
        token_data = token_service.generate_token(seance_params[:client_id])
        render json: token_data, status: :created
      rescue ArgumentError => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      def validate
        token = extract_token_from_header
        return render_unauthorized("token is required") unless token

        result = token_service.validate_token(token)
        if result[:valid]
          render json: result
        else
          render_unauthorized(result[:error])
        end
      end

      private

      def seance_params
        params.permit(:client_id)
      end

      def token_service
        @token_service ||= SeanceTokenService.new
      end

      def extract_token_from_header
        auth_header = request.headers["authorization"]
        return nil unless auth_header

        auth_header.split(" ").last
      end

      def render_unauthorized(message)
        render json: { error: message }, status: :unauthorized
      end
    end
  end
end
