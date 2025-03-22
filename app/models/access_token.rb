class AccessToken < ApplicationRecord
  belongs_to :authorization

  validates :token, presence: true, uniqueness: true
  validates :refresh_token, presence: true, uniqueness: true
  validates :scope, presence: true
  validates :expires_at, presence: true

  def expired?
    expires_at < Time.current
  end

  def expires_in
    (expires_at - Time.current).to_i
  end

  def valid_scope?(required_scope)
    scope.split(" ").include?(required_scope)
  end
end
