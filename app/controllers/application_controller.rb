class ApplicationController < ActionController::API
        include DeviseTokenAuth::Concerns::SetUserByToken
  include ActionController::MimeResponds
  include Pundit::Authorization
  include ErrorHandler
  include TestAuthentication if Rails.env.test?

  before_action :set_default_format

  private

  def set_default_format
    request.format = :json unless request.format.json?
  end
end
