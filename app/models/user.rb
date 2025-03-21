class User < ApplicationRecord
  has_secure_password validations: false

  belongs_to :identity_provider, optional: true
  has_many :card_readings
  has_many :spreads
  has_many :readings
  has_many :cards, through: :card_readings
  has_many :subscriptions
  has_many :active_storage_attachments, as: :record
  has_many :active_storage_blobs, through: :active_storage_attachments
  has_one :reading_quota

  # Track created agent users
  belongs_to :created_by, class_name: "User", foreign_key: "created_by_user_id", optional: true
  has_many :created_agents, class_name: "User", foreign_key: "created_by_user_id"

  validates :external_id, uniqueness: { scope: :identity_provider_id }, allow_nil: true
  validates :email, uniqueness: true, allow_nil: true
  validates :password, presence: true, length: { minimum: 6 }, if: :registered?

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

  def generate_token(expiry: 24.hours.from_now)
    Auth::JwtService.encode(
      user_id: id,
      email: email,
      identity_provider: identity_provider&.name,
      exp: expiry.to_i
    )
  end

  def generate_refresh_token
    refresh = SecureRandom.hex(24)
    update(refresh_token: refresh, token_expiry: 30.days.from_now)
    refresh
  end

  def self.from_token(token)
    return nil if token.blank?

    payload = Auth::JwtService.decode(token)
    return nil unless payload

    find_by(id: payload[:user_id])
  end

  # Usage tracking methods

  # Count readings in the current billing period
  def readings_count_this_period
    # Get active subscription or return all readings if no subscription
    active_subscription = subscriptions.find_by(status: "active")

    if active_subscription
      # Count readings in the current subscription period
      period_start = active_subscription.current_period_start
      period_end = active_subscription.current_period_end

      readings.where(created_at: period_start..period_end).count
    else
      # For users without a subscription, just count all readings from the last 30 days
      readings.where(created_at: 30.days.ago..Time.current).count
    end
  end

  # Get reading limit based on subscription plan
  def reading_limit
    # Find active subscription
    subscription = subscriptions.find_by(status: "active")

    if subscription
      # Return limit based on plan name
      case subscription.plan_name.downcase
      when "basic"
        10
      when "premium"
        50
      when "unlimited"
        Float::INFINITY
      else
        5 # Default for unknown plans
      end
    elsif agent?
      # Agent users get a higher limit by default
      100
    elsif registered?
      # Registered users without a subscription get a limited free tier
      3
    else
      # Anonymous users
      1
    end
  end

  # Check if user has exceeded their reading limit
  def reading_limit_exceeded?
    readings_count_this_period >= reading_limit
  end

  # Increment the reading counter for this user
  def increment_reading_count!
    # If we track with a counter column
    if respond_to?(:readings_count)
      increment!(:readings_count)
    end

    # The reading itself will be tracked through the readings relationship
    # We just need to check if they've exceeded their limit
    if reading_limit_exceeded?
      return false
    end

    true
  end

  def readings_this_period(period_start = Time.current.beginning_of_month, period_end = Time.current.end_of_month)
    readings.where(created_at: period_start..period_end).count
  end

  def readings_this_month
    readings.where(created_at: 30.days.ago..Time.current).count
  end
end
