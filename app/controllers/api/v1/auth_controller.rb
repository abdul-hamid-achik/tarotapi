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

  private

  def user_params
    params.require(:user).permit(:email, :password, :password_confirmation)
  end
end
