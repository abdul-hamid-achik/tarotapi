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
  throttle("reading_sessions/ip", limit: 60, period: 5.minutes) do |req|
    if req.post? && req.path.start_with?("/api/v1/reading_sessions")
      req.ip
    end
  end

  ### custom response
  self.throttled_responder = lambda do |env|
    now = Time.current
    match_data = env["rack.attack.match_data"]

    headers = {
      "content-type" => "application/json",
      "x-ratelimit-limit" => match_data[:limit].to_s,
      "x-ratelimit-remaining" => (match_data[:limit] - match_data[:count]).to_s,
      "x-ratelimit-reset" => (now + (match_data[:period] - now.to_i % match_data[:period])).to_s
    }

    [ 429, headers, [ {
      error: "rate limit exceeded. please try again in #{(match_data[:period] - now.to_i % match_data[:period]).to_i} seconds",
      retry_after: (match_data[:period] - now.to_i % match_data[:period]).to_i
    }.to_json ] ]
  end

  ### safelist certain ips (optional)
  # safelist('allow from localhost') do |req|
  #   '127.0.0.1' == req.ip || '::1' == req.ip
  # end
end
