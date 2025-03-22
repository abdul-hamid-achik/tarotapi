class Api::V1::AuthController < ApplicationController
  def register
    user = User.new(user_params)
    user.provider = 'email'
    user.uid = params[:user][:email]
    user.identity_provider = IdentityProvider.registered

    if user.save
      # Use devise_token_auth to generate tokens
      token = user.create_new_auth_token
      refresh_token = user.generate_refresh_token

      render json: {
        token: token["access-token"],
        client: token["client"],
        uid: token["uid"],
        refresh_token: refresh_token,
        user: { id: user.id, email: user.email }
      }, status: :created
    else
      render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def login
    user = User.find_by(email: params[:email])

    if user&.valid_password?(params[:password])
      # Use devise_token_auth to generate tokens
      token = user.create_new_auth_token
      refresh_token = user.generate_refresh_token

      render json: {
        token: token["access-token"],
        client: token["client"],
        uid: token["uid"],
        refresh_token: refresh_token,
        user: { id: user.id, email: user.email }
      }
    else
      render json: { error: "invalid email or password" }, status: :unauthorized
    end
  end

  def refresh
    user = User.find_by(refresh_token: params[:refresh_token])

    if user && user.token_expiry&.future?
      # Use devise_token_auth to generate a new token
      token = user.create_new_auth_token

      render json: { 
        token: token["access-token"],
        client: token["client"],
        uid: token["uid"]
      }
    else
      render json: { error: "invalid or expired refresh token" }, status: :unauthorized
    end
  end

  def profile
    # Authenticate with either token auth or basic auth
    authenticate_request
    
    if @current_user
      render json: {
        id: @current_user.id,
        email: @current_user.email,
        identity_provider: @current_user.identity_provider&.name
      }
    else
      render json: { error: "unauthorized" }, status: :unauthorized
    end
  end

  # Create or manage agent API credentials
  def create_agent
    # Ensure the current user has permission to create agents
    authenticate_request
    
    unless @current_user && @current_user.registered?
      return render json: { error: "unauthorized" }, status: :unauthorized
    end

    # Generate an external_id for the agent
    external_id = SecureRandom.hex(12)

    # Create the agent user
    agent_user = User.create!(
      identity_provider: IdentityProvider.agent,
      external_id: external_id,
      email: params[:email],
      password: params[:password],
      password_confirmation: params[:password_confirmation],
      provider: 'agent',
      uid: params[:email] || external_id,
      created_by_user_id: @current_user.id
    )

    if agent_user.persisted?
      # Generate a long-lived token for API access
      api_token = agent_user.create_new_auth_token

      render json: {
        agent_id: agent_user.id,
        external_id: external_id,
        email: agent_user.email,
        token: api_token["access-token"],
        client: api_token["client"],
        uid: api_token["uid"]
      }, status: :created
    else
      render json: { errors: agent_user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:email, :password, :password_confirmation)
  end
  
  def authenticate_request
    # Include the AuthenticateRequest concern
    @current_user = User.find_by_uid(uid) if uid
    
    # If no user found with uid, try checking the Authorization header for a token
    unless @current_user
      token = request.headers["Authorization"]&.split(" ")&.last
      @current_user = User.from_token(token) if token
    end
    
    # Still no user? Try API key
    unless @current_user
      api_key_token = request.headers["X-API-Key"]
      if api_key_token
        api_key = ApiKey.valid_for_use.find_by(token: api_key_token)
        @current_user = api_key&.user
      end
    end
  end
  
  def uid
    request.headers["uid"]
  end
end
