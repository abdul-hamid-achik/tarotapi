class IdentityProvider < ApplicationRecord
  has_many :users

  validates :name, presence: true, uniqueness: true

  # predefined provider types
  ANONYMOUS = "anonymous"
  REGISTERED = "registered"
  AGENT = "agent"

  def self.anonymous
    find_or_create_by!(name: ANONYMOUS) do |provider|
      provider.description = "anonymous users with temporary ids"
    end
  end

  def self.registered
    find_or_create_by!(name: REGISTERED) do |provider|
      provider.description = "registered users with permanent accounts"
    end
  end

  def self.agent
    find_or_create_by!(name: AGENT) do |provider|
      provider.description = "agent users for api integrations"
    end
  end
end
