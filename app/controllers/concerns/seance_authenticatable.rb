module SeanceAuthenticatable
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_seance!
  end

  private

  def authenticate_seance!
    token = extract_token_from_header
    return unauthorized_error('token is required') unless token

    result = token_service.validate_token(token)
    return unauthorized_error(result[:error]) unless result[:valid]

    @current_client_id = result[:client_id]
  end

  def current_client_id
    @current_client_id
  end

  def token_service
    @token_service ||= SeanceTokenService.new
  end

  def extract_token_from_header
    auth_header = request.headers['authorization']
    return nil unless auth_header
    
    auth_header.split(' ').last
  end

  def unauthorized_error(message)
    render json: { error: message }, status: :unauthorized
  end
end 