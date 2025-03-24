module TestAuthentication
  extend ActiveSupport::Concern

  included do
    attr_writer :current_user
  end

  def authenticate_request
    # No authentication in tests unless explicitly set
    true
  end

  def current_user
    # Ensure a user is available for tests
    @current_user ||= defined?(FactoryBot) ? FactoryBot.create(:user) : nil
  end

  # DeviseTokenAuth method stub for tests
  def authenticate_api_v1_user!
    true
  end

  # For Pundit
  def pundit_user
    current_user
  end
end
