class Auth::JwtService
  class << self
    def encode(payload, exp = 24.hours.from_now)
      payload[:exp] = exp.to_i
      JWT.encode(payload, jwt_secret)
    end

    def decode(token)
      decoded = JWT.decode(token, jwt_secret)[0]
      HashWithIndifferentAccess.new(decoded)
    rescue JWT::DecodeError, JWT::ExpiredSignature
      nil
    end

    def jwt_secret
      Rails.application.credentials.secret_key_base || ENV.fetch("SECRET_KEY_BASE")
    end
  end
end
