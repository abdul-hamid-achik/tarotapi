class IdentityProvider < ApplicationRecord
  has_many :users

  validates :name, presence: true, uniqueness: true

  # predefined provider types
  ANONYMOUS = "anonymous"
  REGISTERED = "registered"
  AGENT = "agent"

  def self.anonymous
    find_or_create_by!(name: ANONYMOUS)
  end

  def self.registered
    find_or_create_by!(name: REGISTERED)
  end

  def self.agent
    find_or_create_by!(name: AGENT)
  end
end
