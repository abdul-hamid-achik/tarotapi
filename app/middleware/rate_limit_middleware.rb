class RateLimitMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    request = Rack::Request.new(env)

    # Skip rate limiting in test environment
    if Rails.env.test? && ENV["SKIP_RATE_LIMIT"] == "true"
      return @app.call(env)
    end

    if should_rate_limit?(request)
      client_identifier = extract_client_identifier(request)
      rate_limit_key = "rate_limit:#{normalized_path(request)}:#{client_identifier}"

      limit, remaining, reset_time = get_rate_limit_info(rate_limit_key, request)

      if remaining <= 0
        return rate_limit_exceeded_response(limit, reset_time)
      end

      # Add rate limit headers to the response
      status, headers, response = @app.call(env)
      headers["X-RateLimit-Limit"] = limit.to_s
      headers["X-RateLimit-Remaining"] = remaining.to_s
      headers["X-RateLimit-Reset"] = reset_time.to_i.to_s
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
    # Use IP address for basic rate limiting in test
    request.ip || "unknown_client"
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
end
