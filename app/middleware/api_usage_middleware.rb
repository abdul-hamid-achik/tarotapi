class ApiUsageMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    request = Rack::Request.new(env)
    start_time = Time.current

    # Process the request
    status, headers, response = @app.call(env)

    # Track API usage after request completes
    track_api_usage(env, request, status, Time.current - start_time)

    # Return the original response
    [ status, headers, response ]
  end

  private

  def track_api_usage(env, request, status, response_time)
    # Skip tracking for health check and non-API endpoints
    return unless api_endpoint?(request.path)

    # Extract user and organization
    user = extract_user(env, request)
    organization = user&.organization if user&.respond_to?(:organization)

    # Skip logging if we don't have an organization
    return unless organization

    # Extract API key if present
    api_key_id = nil
    if request.env["HTTP_X_API_KEY"].present?
      api_key = ApiKey.find_by(key: request.env["HTTP_X_API_KEY"])
      api_key_id = api_key.id if api_key
    end

    # Track the API usage
    ApiUsageService.track_request(
      organization,
      user,
      request.path,
      status,
      response_time * 1000, # Convert to milliseconds
      api_key_id
    )

    # Track session usage for streaming endpoints
    if streaming_endpoint?(request.path) && status.to_i >= 200 && status.to_i < 300
      UsageLog.record_session!(organization: organization, user: user)
    end

    # Track reading creation
    if reading_endpoint?(request) && status.to_i == 201
      UsageLog.record_reading!(organization: organization, user: user)
    end
  end

  def api_endpoint?(path)
    path.start_with?("/api/v1") && !path.include?("/health")
  end

  def streaming_endpoint?(path)
    path.match?(%r{/api/v1/readings/\d+/interpret_streaming})
  end

  def reading_endpoint?(request)
    request.post? &&
    request.path.match?(%r{/api/v1/readings}) &&
    !request.path.include?("/interpret")
  end

  def extract_user(env, request)
    # Try to get user from warden
    user = env["warden"]&.user

    # If no user from warden, try from API key
    if user.nil? && request.env["HTTP_X_API_KEY"].present?
      api_key = ApiKey.find_by(key: request.env["HTTP_X_API_KEY"])
      user = api_key&.user
    end

    # If still no user, try from Authorization header (JWT)
    if user.nil? && request.env["HTTP_AUTHORIZATION"].present?
      token = request.env["HTTP_AUTHORIZATION"].split(" ").last
      begin
        decoded_token = JWT.decode(token, Rails.application.credentials.secret_key_base).first
        user = User.find_by(id: decoded_token["user_id"]) if decoded_token["user_id"]
      rescue JWT::DecodeError
        # Invalid token, no user
      end
    end

    user
  end
end
