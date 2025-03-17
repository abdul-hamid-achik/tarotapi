class SeanceTokenService
  TOKEN_EXPIRATION = 1.hour
  
  def initialize
    @redis = Redis.new(url: ENV['REDIS_URL'])
  end

  def generate_token(client_id)
    validate_client_id!(client_id)
    
    existing_token = find_token_by_client_id(client_id)
    return existing_token if existing_token && !token_expired?(existing_token[:expires_at])

    token_data = create_token(client_id)
    store_token(token_data)
    token_data
  end

  def validate_token(token)
    token_data = retrieve_token(token)
    return invalid_token('token not found') unless token_data
    return invalid_token('token expired') if token_expired?(token_data[:expires_at])

    { valid: true, client_id: token_data[:client_id] }
  end

  def clear_expired_tokens
    pattern = "seance:token:*"
    @redis.scan_each(match: pattern) do |key|
      token_data = JSON.parse(@redis.get(key), symbolize_names: true)
      @redis.del(key) if token_expired?(token_data[:expires_at])
    end
  end

  private

  def validate_client_id!(client_id)
    unless client_id.match?(/\A[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i)
      raise ArgumentError, 'invalid client_id format'
    end
  end

  def find_token_by_client_id(client_id)
    pattern = "seance:token:*"
    @redis.scan_each(match: pattern) do |key|
      token_data = JSON.parse(@redis.get(key), symbolize_names: true)
      return token_data if token_data[:client_id] == client_id
    end
    nil
  end

  def create_token(client_id)
    {
      token: generate_unique_token,
      client_id: client_id,
      expires_at: Time.current + TOKEN_EXPIRATION
    }
  end

  def generate_unique_token
    SecureRandom.urlsafe_base64(32)
  end

  def store_token(token_data)
    key = "seance:token:#{token_data[:token]}"
    @redis.set(key, token_data.to_json, ex: TOKEN_EXPIRATION.to_i)
  end

  def retrieve_token(token)
    key = "seance:token:#{token}"
    data = @redis.get(key)
    data ? JSON.parse(data, symbolize_names: true) : nil
  end

  def token_expired?(expires_at)
    Time.parse(expires_at.to_s) <= Time.current
  end

  def invalid_token(reason)
    { valid: false, error: reason }
  end
end 