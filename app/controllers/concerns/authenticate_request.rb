module AuthenticateRequest
  extend ActiveSupport::Concern
  include ActionController::HttpAuthentication::Basic::ControllerMethods

  included do
    before_action :authenticate_request
    attr_reader :current_user
  end

  private

  def authenticate_request
    # Try JWT authentication first
    @current_user = authenticate_with_jwt

    # If JWT fails, try HTTP Basic Auth (especially for agent access)
    @current_user ||= authenticate_with_http_basic

    render json: { error: "unauthorized" }, status: :unauthorized unless @current_user
  end

  def authenticate_with_jwt
    User.from_token(token)
  end

  def authenticate_with_http_basic
    user = nil

    # Use Rails HTTP Basic Authentication
    ActionController::HttpAuthentication::Basic.authenticate(request) do |email, password|
      # Find user by email
      user = User.find_by(email: email)

      if user&.authenticate(password)
        # If it's an agent user with valid credentials, use it
        if user.agent?
          return user
        # Or if it's a registered user with valid credentials
        elsif user.registered?
          return user
        end
      end

      nil
    end

    user
  end

  def token
    request.headers["Authorization"]&.split(" ")&.last
  end
end
