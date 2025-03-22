class Authorization < ApplicationRecord
  belongs_to :user
  has_many :access_tokens, dependent: :destroy

  validates :code, presence: true, uniqueness: true
  validates :client_id, presence: true
  validates :scope, presence: true
  validates :expires_at, presence: true

  def expired?
    expires_at < Time.current
  end

  def generate_access_token!
    access_tokens.create!(
      token: SecureRandom.hex(32),
      refresh_token: SecureRandom.hex(32),
      scope: scope,
      expires_at: 2.hours.from_now
    )
  end
end
