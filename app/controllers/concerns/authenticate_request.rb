module AuthenticateRequest
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_request
    attr_reader :current_user
  end

  private

  def authenticate_request
    @current_user = User.from_token(token)

    render json: { error: "unauthorized" }, status: :unauthorized unless @current_user
  end

  def token
    request.headers["Authorization"]&.split(" ")&.last
  end
end
