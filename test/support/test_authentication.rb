module TestAuthentication
  extend ActiveSupport::Concern

  included do
    attr_writer :current_user

    # Add helper methods for tests
    helper_method :current_user if respond_to?(:helper_method)

    # Skip authentication in tests
    skip_before_action :authenticate_user!, raise: false if respond_to?(:skip_before_action)
    skip_before_action :authenticate_api_v1_user!, raise: false if respond_to?(:skip_before_action)
    skip_before_action :authenticate_request, raise: false if respond_to?(:skip_before_action)

    # Skip pundit verification in tests
    skip_after_action :verify_authorized, raise: false if respond_to?(:skip_after_action)
    skip_after_action :verify_policy_scoped, raise: false if respond_to?(:skip_after_action)
  end

  def authenticate_request
    # For integration tests, check for fake token
    if request.headers["Authorization"]&.include?("test_token")
      return true
    end

    # No authentication in tests unless explicitly set
    true
  end

  def current_user
    # For integration tests, check for auth header
    if request.headers["Authorization"]&.include?("test_token")
      return defined?(User) ? User.first || User.create(email: "test@example.com", password: "password") : nil
    end

    # Ensure a user is available for tests
    @current_user ||= defined?(User) ? User.first || User.create(email: "test@example.com", password: "password") : nil
  end

  # DeviseTokenAuth method stub for tests
  def authenticate_api_v1_user!
    # For integration tests, check for fake token
    if request.headers["Authorization"]&.include?("test_token")
      return true
    end

    true
  end

  # Handle authenticate_user! from Devise
  def authenticate_user!
    # For integration tests, check for fake token
    if request.headers["Authorization"]&.include?("test_token")
      return true
    end

    true
  end

  # For Pundit
  def pundit_user
    current_user
  end

  # Define policy method for Pundit that always allows actions
  def policy(record)
    OpenStruct.new(
      index?: true, show?: true, create?: true,
      new?: true, update?: true, edit?: true, destroy?: true,
      permitted_attributes: record.respond_to?(:attributes) ? record.attributes.keys : []
    )
  end

  # Define policy_scope method for Pundit
  def policy_scope(scope)
    scope
  end

  # Define authorize method for Pundit
  def authorize(record, query = nil)
    true
  end

  # For integration tests
  def sign_in(user)
    @current_user = user
  end

  def sign_out
    @current_user = nil
  end
end
