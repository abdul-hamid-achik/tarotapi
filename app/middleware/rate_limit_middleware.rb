class RateLimitMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    request = Rack::Request.new(env)
    start_time = Time.current

    # Skip rate limiting in test environment
    if Rails.env.test? && ENV["SKIP_RATE_LIMIT"] == "true"
      return @app.call(env)
    end

    if should_rate_limit?(request)
      client_identifier = extract_client_identifier(request)
      rate_limit_key = "rate_limit:#{normalized_path(request)}:#{client_identifier}"

      limit, remaining, reset_time = get_rate_limit_info(rate_limit_key, request)

      if remaining <= 0
        response = rate_limit_exceeded_response(limit, reset_time)
        # Log rate limit exceeded events
        log_rate_limit_exceeded(env, request)
        return response
      end

      # Add rate limit headers to the response
      status, headers, response = @app.call(env)
      headers["X-RateLimit-Limit"] = limit.to_s
      headers["X-RateLimit-Remaining"] = remaining.to_s
      headers["X-RateLimit-Reset"] = reset_time.to_i.to_s

      # Track API usage after successful request
      track_api_usage(env, request, status, Time.current - start_time)

      [ status, headers, response ]
    else
      @app.call(env)
    end
  end

  private

  def should_rate_limit?(request)
    # Define paths that should be rate limited
    rate_limited_paths = [
      %r{^/api/v1/seance},
      %r{^/api/v1/reading_sessions},
      %r{^/api/v1/}
    ]

    rate_limited_paths.any? { |pattern| request.path.match?(pattern) }
  end

  def extract_client_identifier(request)
    # Try to identify the client by API key or user token first
    api_key = request.env["HTTP_X_API_KEY"]
    auth_header = request.env["HTTP_AUTHORIZATION"]

    if api_key.present?
      "api_key:#{api_key}"
    elsif auth_header.present? && auth_header.start_with?("Bearer ")
      "token:#{auth_header.split(" ").last}"
    else
      # Fall back to IP address
      "ip:#{request.ip || 'unknown_client'}"
    end
  end

  def normalized_path(request)
    if request.path.match?(%r{^/api/v1/seance})
      "seance"
    elsif request.path.match?(%r{^/api/v1/reading_sessions})
      "reading_sessions"
    else
      "api_general"
    end
  end

  def get_rate_limit_info(key, request)
    # In test environment, we're using Mock Redis
    redis = Redis.new

    # Define limits based on endpoint type
    limit = case normalized_path(request)
    when "seance"
              30
    when "reading_sessions"
              60
    else
              300
    end

    window = 3600 # 1 hour in seconds

    # Get current count or initialize
    count = redis.get(key).to_i || 0

    # If key doesn't exist, set it with expiration
    if count == 0
      redis.setex(key, window, 1)
      count = 1
    else
      # Increment counter
      redis.incr(key)
      count += 1
    end

    # Get time to reset (TTL of the key)
    ttl = redis.ttl(key)
    reset_time = Time.now + ttl

    remaining = [ limit - count, 0 ].max

    [ limit, remaining, reset_time ]
  end

  def rate_limit_exceeded_response(limit, reset_time)
    headers = {
      "Content-Type" => "application/json",
      "X-RateLimit-Limit" => limit.to_s,
      "X-RateLimit-Remaining" => "0",
      "X-RateLimit-Reset" => reset_time.to_i.to_s
    }

    body = {
      error: "rate limit exceeded",
      retry_after: (reset_time - Time.now).ceil
    }.to_json

    [ 429, headers, [ body ] ]
  end

  def track_api_usage(env, request, status, response_time)
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
  end

  def log_rate_limit_exceeded(env, request)
    # Extract user and organization
    user = extract_user(env, request)
    organization = user&.organization if user&.respond_to?(:organization)

    # Skip logging if we don't have an organization
    return unless organization

    # Log the rate limit exceeded event
    UsageLog.record_error!(
      organization: organization,
      user: user,
      error_message: "Rate limit exceeded",
      endpoint: request.path
    )
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
      user = User.from_token(token) if token
    end

    user
  end
end
