class ApplicationController < ActionController::API
        include DeviseTokenAuth::Concerns::SetUserByToken
  include ActionController::MimeResponds
  include Pundit::Authorization

  before_action :set_default_format

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
  rescue_from ActiveRecord::RecordNotFound, with: :not_found

  private

  def set_default_format
    request.format = :json unless request.format.json?
  end

  def user_not_authorized(exception)
    policy_name = exception.policy.class.to_s.underscore
    error_message = case policy_name
    when "reading_policy"
      if exception.query == "create?"
        "You have reached your reading limit or don't have access to this spread type"
      elsif exception.query == "stream?"
        "Streaming requires a premium subscription"
      elsif exception.query == "export_pdf?"
        "PDF export requires a premium subscription"
      elsif exception.query == "advanced_interpretation?"
        "Advanced interpretation requires a professional subscription"
      else
        "You are not authorized to perform this action on this reading"
      end
    when "spread_policy"
      if exception.query == "create?"
        "Creating custom spreads requires a premium subscription"
      elsif exception.query == "publish?"
        "Publishing spreads requires a professional subscription"
      else
        "You are not authorized to perform this action on this spread"
      end
    when "subscription_policy"
      if exception.query == "create?"
        "You already have an active subscription"
      elsif exception.query == "reactivate?"
        "You cannot reactivate this subscription while another is active"
      else
        "You are not authorized to perform this action on this subscription"
      end
    else
      "You are not authorized to perform this action"
    end

    render json: { error: "unauthorized", message: error_message }, status: :unauthorized
  end

  def not_found
    render json: { error: "not_found", message: "The requested resource could not be found" }, status: :not_found
  end
end
