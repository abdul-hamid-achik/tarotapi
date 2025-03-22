class ApplicationController < ActionController::API
        include DeviseTokenAuth::Concerns::SetUserByToken
  include ActionController::MimeResponds

  before_action :set_default_format

  private

  def set_default_format
    request.format = :json unless request.format.json?
  end
end
