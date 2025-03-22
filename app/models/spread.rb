class Spread < ApplicationRecord
  include Cacheable
  
  belongs_to :user, optional: true
  has_many :card_readings, dependent: :nullify
  has_many :readings

  validates :name, presence: true, uniqueness: true
  validates :description, presence: true
  validates :positions, presence: true
  validates :is_public, inclusion: { in: [ true, false ] }
  validates :num_cards, presence: true, numericality: { greater_than: 0 }

  scope :system, -> { where(is_system: true) }
  scope :custom_spreads, -> { where(is_system: false) }
  scope :public_spreads, -> { where(is_public: true) }
  scope :default_available, -> { where(is_system: true).or(where(is_public: true)) }
  scope :accessible_by, ->(user) { where("is_public = ? OR is_system = ? OR user_id = ?", true, true, user.id) }

  def self.default_spread
    SpreadService.default_spread
  end

  def system?
    is_system
  end

  # Find public and system spreads with caching
  def self.available_spreads_cached
    cached_query("available_spreads", expires_in: 12.hours) do
      default_available.order(:name)
    end
  end

  # Find all spreads by a user with caching
  def self.user_spreads_cached(user_id)
    cached_query("user_#{user_id}_spreads", expires_in: 1.hour) do
      where(user_id: user_id).order(:created_at)
    end
  end
end
