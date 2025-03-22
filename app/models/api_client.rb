class ApiClient < ApplicationRecord
  belongs_to :organization
  has_many :authorizations, dependent: :destroy
  has_many :access_tokens, through: :authorizations

  validates :name, presence: true
  validates :client_id, presence: true, uniqueness: true
  validates :client_secret, presence: true
  validates :redirect_uri, presence: true, format: URI::DEFAULT_PARSER.make_regexp(%w[http https])

  before_validation :generate_credentials, on: :create

  def valid_secret?(secret)
    return false if client_secret.nil?
    BCrypt::Password.new(client_secret).is_password?(secret)
  end

  private

  def generate_credentials
    self.client_id = SecureRandom.hex(32)
    self.client_secret = BCrypt::Password.create(SecureRandom.hex(32))
  end
end
