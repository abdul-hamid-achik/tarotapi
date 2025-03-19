class User < ApplicationRecord
  has_secure_password validations: false

  belongs_to :identity_provider, optional: true
  has_many :card_readings
  has_many :spreads
  has_many :reading_sessions
  has_many :tarot_cards, through: :card_readings
  has_many :subscriptions

  validates :external_id, uniqueness: { scope: :identity_provider_id }, allow_nil: true
  validates :email, uniqueness: true, allow_nil: true
  validates :password, presence: true, length: { minimum: 6 }, if: :registered?

  def self.find_or_create_anonymous(external_id = nil)
    external_id ||= SecureRandom.uuid

    find_or_create_by!(
      identity_provider: IdentityProvider.anonymous,
      external_id: external_id
    )
  end

  def self.find_or_create_agent(external_id)
    find_or_create_by!(
      identity_provider: IdentityProvider.agent,
      external_id: external_id
    )
  end

  def anonymous?
    identity_provider&.name == IdentityProvider::ANONYMOUS
  end

  def agent?
    identity_provider&.name == IdentityProvider::AGENT
  end

  def registered?
    identity_provider&.name == IdentityProvider::REGISTERED
  end

  def generate_token
    Auth::JwtService.encode(
      user_id: id,
      email: email,
      identity_provider: identity_provider&.name
    )
  end

  def generate_refresh_token
    refresh = SecureRandom.hex(24)
    update(refresh_token: refresh, token_expiry: 30.days.from_now)
    refresh
  end

  def self.from_token(token)
    return nil if token.blank?

    payload = Auth::JwtService.decode(token)
    return nil unless payload

    find_by(id: payload[:user_id])
  end
end
