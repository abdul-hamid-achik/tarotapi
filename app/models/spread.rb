class Spread < ApplicationRecord
  belongs_to :user
  has_many :card_readings, dependent: :nullify
  has_many :readings

  validates :name, presence: true, uniqueness: true
  validates :description, presence: true
  validates :positions, presence: true
  validates :is_public, inclusion: { in: [ true, false ] }

  scope :system_spreads, -> { where(is_system: true) }
  scope :custom_spreads, -> { where(is_system: false) }
  scope :public_spreads, -> { where(is_public: true) }

  def self.default_spread
    SpreadService.default_spread
  end

  def system?
    is_system
  end
end
