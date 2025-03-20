class ReadingQuotaMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    request = Rack::Request.new(env)
    
    # Only intercept tarot reading creation requests
    if reading_request?(request)
      user = current_user(request)
      
      if user && !user.subscription_status == "active"
        # Check if user has remaining quota
        quota = ReadingQuota.find_or_create_by(user_id: user.id) do |q|
          q.monthly_limit = ENV.fetch("DEFAULT_FREE_TIER_LIMIT", 100).to_i
          q.readings_this_month = 0
          q.reset_date = Date.today.end_of_month + 1.day
        end
        
        if quota.exceeded?
          # Return quota exceeded error
          return quota_exceeded_response(request)
        end
      end
    end
    
    # Process the request normally
    status, headers, response = @app.call(env)
    
    # If this was a successful reading creation, increment the counter
    if reading_creation_successful?(request, status)
      user = current_user(request)
      if user && user.subscription_status != "active"
        increment_quota(user)
      end
    end
    
    [status, headers, response]
  end
  
  private
  
  def reading_request?(request)
    request.post? && 
    request.path.match?(/\A\/api\/v1\/readings\z/) &&
    request.content_type&.include?('application/json')
  end
  
  def reading_creation_successful?(request, status)
    reading_request?(request) && status == 201
  end
  
  def current_user(request)
    # Extract user from authentication logic
    # This will depend on your authentication system
    auth_header = request.get_header("HTTP_AUTHORIZATION")
    return nil unless auth_header
    
    token = auth_header.split(' ').last
    payload = JWT.decode(token, Rails.application.credentials.secret_key_base).first
    
    User.find_by(id: payload["user_id"])
  rescue JWT::DecodeError
    nil
  end
  
  def increment_quota(user)
    quota = ReadingQuota.find_by(user_id: user.id)
    return unless quota
    
    quota.increment_usage!
    
    # If user is approaching their limit, include a header in subsequent responses
    Rails.logger.info("User #{user.id} has #{quota.remaining} readings left this month")
  end
  
  def quota_exceeded_response(request)
    content_type = request.get_header("HTTP_ACCEPT") || "application/json"
    
    if content_type.include?("application/json")
      [
        402, # Payment Required
        { "Content-Type" => "application/json" },
        [{ 
          error: "quota_exceeded",
          message: "You've reached your monthly limit of free readings. Please upgrade to continue.",
          upgrade_url: "/subscriptions/new"
        }.to_json]
      ]
    else
      [
        402, # Payment Required
        { "Content-Type" => "text/plain" },
        ["You've reached your monthly limit of free readings. Please upgrade to continue."]
      ]
    end
  end
end 