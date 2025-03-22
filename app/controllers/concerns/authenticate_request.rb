module AuthenticateRequest
  extend ActiveSupport::Concern
  include ActionController::HttpAuthentication::Basic::ControllerMethods
  include DeviseTokenAuth::Concerns::SetUserByToken

  included do
    before_action :authenticate_request
    attr_reader :current_user
    attr_reader :current_api_key
  end

  private

  def authenticate_request
    # Try JWT/token authentication first via devise_token_auth
    @current_user = authenticate_with_token

    # If token auth fails, try API key authentication
    @current_user ||= authenticate_with_api_key

    # If API key fails, try HTTP Basic Auth (especially for agent access)
    @current_user ||= authenticate_with_http_basic

    render json: { error: "unauthorized" }, status: :unauthorized unless @current_user
  end

  def authenticate_with_token
    # Let devise_token_auth handle the token authentication
    # It will set @resource which we can use to get the current user
    set_user_by_token
    @resource
  end

  def authenticate_with_api_key
    api_key_token = request.headers["X-API-Key"]
    return nil unless api_key_token

    # Find a valid API key
    api_key = ApiKey.valid_for_use.find_by(token: api_key_token)
    return nil unless api_key

    # Record usage
    api_key.record_usage!

    # Store the API key for potential rate limiting or tracking
    @current_api_key = api_key

    # Return the user associated with this API key
    api_key.user
  end

  def authenticate_with_http_basic
    user = nil

    # Use Rails HTTP Basic Authentication
    ActionController::HttpAuthentication::Basic.authenticate(request) do |email, password|
      # Find user by email
      user = User.find_by(email: email)

      if user&.valid_password?(password)
        # If it's an agent user, require an API key as well
        if user.agent?
          api_key_token = request.headers["X-API-Key"]
          return nil unless api_key_token

          # Find a valid API key belonging to this user
          api_key = user.api_keys.valid_for_use.find_by(token: api_key_token)
          return nil unless api_key

          # Record usage
          api_key.record_usage!

          # Store the API key for potential rate limiting or tracking
          @current_api_key = api_key

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
