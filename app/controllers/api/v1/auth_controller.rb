class Api::V1::AuthController < ApplicationController
  def register
    user = User.new(user_params)
    user.identity_provider = IdentityProvider.registered

    if user.save
      token = user.generate_token
      refresh_token = user.generate_refresh_token

      render json: {
        token: token,
        refresh_token: refresh_token,
        user: { id: user.id, email: user.email }
      }, status: :created
    else
      render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def login
    user = User.find_by(email: params[:email])

    if user&.authenticate(params[:password])
      token = user.generate_token
      refresh_token = user.generate_refresh_token

      render json: {
        token: token,
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
      token = user.generate_token

      render json: { token: token }
    else
      render json: { error: "invalid or expired refresh token" }, status: :unauthorized
    end
  end

  def profile
    user = User.from_token(request.headers["Authorization"]&.split(" ")&.last)

    if user
      render json: {
        id: user.id,
        email: user.email,
        identity_provider: user.identity_provider&.name
      }
    else
      render json: { error: "unauthorized" }, status: :unauthorized
    end
  end

  # Create or manage agent API credentials
  def create_agent
    # Ensure the current user has permission to create agents
    user = User.from_token(request.headers["Authorization"]&.split(" ")&.last)

    unless user && user.registered?
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
      created_by_user_id: user.id
    )

    if agent_user.persisted?
      # Generate a long-lived token for API access
      api_token = agent_user.generate_token(expiry: 1.year.from_now)

      render json: {
        agent_id: agent_user.id,
        external_id: external_id,
        email: agent_user.email,
        api_token: api_token
      }, status: :created
    else
      render json: { errors: agent_user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:email, :password, :password_confirmation)
  end
end
