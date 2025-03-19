class UserSerializer
  include JSONAPI::Serializer

  attributes :email, :external_id, :created_at, :updated_at

  belongs_to :identity_provider
  has_many :card_readings
  has_many :spreads
  has_many :reading_sessions

  attribute :user_type do |user|
    if user.anonymous?
      "anonymous"
    elsif user.agent?
      "agent"
    else
      "registered"
    end
  end
end
