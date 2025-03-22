module ErrorHandler
  extend ActiveSupport::Concern
  include TarotErrors

  included do
    # Standard Error Handling
    rescue_from StandardError, with: :handle_standard_error
    rescue_from Pundit::NotAuthorizedError, with: :handle_unauthorized
    rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
    rescue_from ActiveRecord::RecordInvalid, with: :handle_validation_error
    rescue_from ActionController::ParameterMissing, with: :handle_parameter_missing
    rescue_from ArgumentError, with: :handle_argument_error
    rescue_from JWT::DecodeError, with: :handle_jwt_error if defined?(JWT)
    rescue_from JWT::ExpiredSignature, with: :handle_jwt_expired if defined?(JWT)
  end

  private

  # Generic error handler
  def handle_standard_error(exception)
    log_error(exception)
    render_tarot_error(500, Rails.env.production? ? nil : exception.message)
  end

  # Common method to log errors with context
  def log_error(exception, context = {})
    context[:user_id] = current_user&.id if defined?(current_user)
    context[:request_id] = request.request_id if request.respond_to?(:request_id)

    error_message = "#{exception.class.name}: #{exception.message}"
    error_context = context.map { |k, v| "#{k}=#{v}" }.join(" ")

    Rails.logger.error("#{error_message} | #{error_context}")

    # Report to error tracking service if available
    Sentry.capture_exception(exception, extra: context) if defined?(Sentry)
  end

  # Authorization errors
  def handle_unauthorized(exception)
    policy_name = exception.policy.class.to_s.underscore
    query = exception.query.to_s

    # Create a more specific message based on policy
    details = case policy_name
    when "reading_policy"
      if query == "create?"
        "You have reached your reading limit or don't have access to this spread type"
      elsif query == "stream?"
        "Streaming requires a premium subscription"
      elsif query == "export_pdf?"
        "PDF export requires a premium subscription"
      elsif query == "advanced_interpretation?"
        "Advanced interpretation requires a professional subscription"
      else
        "You are not authorized to perform this action on this reading"
      end
    when "spread_policy"
      if query == "create?"
        "Creating custom spreads requires a premium subscription"
      elsif query == "publish?"
        "Publishing spreads requires a professional subscription"
      else
        "You are not authorized to perform this action on this spread"
      end
    when "subscription_policy"
      if query == "create?"
        "You already have an active subscription"
      elsif query == "reactivate?"
        "You cannot reactivate this subscription while another is active"
      else
        "You are not authorized to perform this action on this subscription"
      end
    else
      "You are not authorized to perform this action"
    end

    log_error(exception, { policy: policy_name, query: query })
    render_tarot_error(403, details) # Use 403 Forbidden for authorization errors
  end

  # 404 Not Found errors
  def handle_not_found(exception)
    model = exception.model.downcase rescue "resource"
    details = "The requested #{model} could not be found"

    log_error(exception, { model: model, id: params[:id] })
    render_tarot_error(404, details)
  end

  # Validation errors
  def handle_validation_error(exception)
    record = exception.record
    errors = record.errors.messages.transform_values { |msgs| msgs.map(&:to_s) }

    log_error(exception, {
      model: record.class.name,
      validation_errors: errors.to_json
    })

    render_tarot_error(422, errors)
  end

  # Missing parameter errors
  def handle_parameter_missing(exception)
    parameter = exception.param
    details = "Required parameter missing: #{parameter}"

    log_error(exception, { parameter: parameter })
    render_tarot_error(400, details)
  end

  # Argument errors
  def handle_argument_error(exception)
    log_error(exception)
    render_tarot_error(400, exception.message)
  end

  # JWT decode errors
  def handle_jwt_error(exception)
    log_error(exception)
    render_tarot_error(401, "Invalid authentication token")
  end

  # JWT expiration errors
  def handle_jwt_expired(exception)
    log_error(exception)
    render_tarot_error(401, "Authentication token has expired. Please refresh your token or log in again.")
  end
end
