class Rack::Attack
  ### configure cache store
  Rack::Attack.cache.store = Redis.new(url: ENV.fetch("REDIS_URL") { "redis://localhost:6379/1" })

  ### throttle settings
  # limit all api endpoints to 300 requests per 5 minutes per ip
  throttle("api/ip", limit: 300, period: 5.minutes) do |req|
    if req.path.start_with?("/api/")
      req.ip
    end
  end

  # stricter limit for seance endpoint (token generation)
  # 30 requests per 5 minutes per ip
  throttle("seance/ip", limit: 30, period: 5.minutes) do |req|
    if req.path.start_with?("/api/v1/seance")
      req.ip
    end
  end

  # limit reading session creation
  # 60 requests per 5 minutes per ip
  throttle("readings/ip", limit: 60, period: 5.minutes) do |req|
    if req.post? && req.path.start_with?("/api/v1/readings")
      req.ip
    end
  end

  ### tarot-themed custom response for rate limiting
  self.throttled_responder = lambda do |env|
    now = Time.current
    match_data = env["rack.attack.match_data"]
    
    seconds_until_reset = (match_data[:period] - now.to_i % match_data[:period]).to_i
    minutes, seconds = seconds_until_reset.divmod(60)
    time_format = if minutes > 0
                    "#{minutes}m #{seconds}s"
                  else
                    "#{seconds}s"
                  end
    
    # Tarot card for rate limiting: Temperance Reversed (patience, balance)
    response_body = {
      error: {
        type: "temperance_reversed",
        title: "Temperance Reversed",
        status: 429,
        emoji: "🔥",
        message: "Patience is a virtue. You've made too many requests too quickly.",
        details: "Please wait #{time_format} before trying again.",
        rate_limit: {
          limit: match_data[:limit],
          remaining: 0,
          reset_after: seconds_until_reset,
          retry_after: seconds_until_reset
        }
      }
    }.to_json
    
    headers = {
      "Content-Type" => "application/json",
      "Content-Length" => response_body.bytesize.to_s,
      "X-RateLimit-Limit" => match_data[:limit].to_s,
      "X-RateLimit-Remaining" => "0",
      "X-RateLimit-Reset" => (now + seconds_until_reset).to_s,
      "Retry-After" => seconds_until_reset.to_s
    }

    [ 429, headers, [response_body] ]
  end

  ### safelist certain ips (optional)
  # safelist('allow from localhost') do |req|
  #   '127.0.0.1' == req.ip || '::1' == req.ip
  # end
end
