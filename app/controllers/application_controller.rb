class ApplicationController < ActionController::API
        include DeviseTokenAuth::Concerns::SetUserByToken
  include ActionController::MimeResponds
  include Pundit::Authorization
  include ErrorHandler
  include Loggable

  # Only include TestAuthentication in test environment, and only for non-integration tests
  # Integration tests should provide auth headers
  if Rails.env == "test"
    include TestAuthentication

    # Add a helper method to skip authentication for test access
    def self.skip_auth_for_test
      skip_before_action :authenticate_request, raise: false if respond_to?(:skip_before_action)
      skip_before_action :authenticate_api_v1_user!, raise: false if respond_to?(:skip_before_action)
      skip_before_action :authenticate_user!, raise: false if respond_to?(:skip_before_action)
    end
  end

  before_action :set_default_format
  before_action :store_request_id
  after_action :log_request

  private

  def set_default_format
    request.format = :json unless request.format.ndjson?
  end

  def store_request_id
    Thread.current[:request_id] = request.request_id
  end

  def log_request
    # Log basic request information
    log_info("Request completed", {
      path: request.path,
      method: request.method,
      format: request.format.to_sym,
      status: response.status,
      duration: (Time.current - request.start_time.to_time).round(2),
      user_id: current_user&.id,
      ip: request.remote_ip
    })
  end
end
