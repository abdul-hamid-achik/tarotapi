class User < ApplicationRecord
  belongs_to :identity_provider, optional: true
  has_many :card_readings
  has_many :spreads
  has_many :reading_sessions
  has_many :tarot_cards, through: :card_readings
  
  validates :external_id, uniqueness: { scope: :identity_provider_id }, allow_nil: true
  validates :email, uniqueness: true, allow_nil: true
  
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
end
