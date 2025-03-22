class SubscriptionPlan < ApplicationRecord
  has_many :subscriptions

  validates :name, presence: true, uniqueness: true
  validates :price, numericality: { greater_than_or_equal_to: 0 }
  validates :price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :monthly_readings, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :duration_days, numericality: { only_integer: true, greater_than: 0 }

  scope :active, -> { where(is_active: true) }

  def free?
    price_cents.zero?
  end

  def features_list
    features
  end

  def has_feature?(feature_name)
    features.include?(feature_name.to_s)
  end

  def unlimited_readings?
    reading_limit.nil?
  end

  def reading_limit
    self[:reading_limit] || monthly_readings
  end

  # Compatibility method for seeds
  def reading_limit=(value)
    self[:reading_limit] = value
    self[:monthly_readings] = value if value.present?
  end
end
