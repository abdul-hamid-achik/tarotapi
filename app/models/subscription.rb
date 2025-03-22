class Subscription < ApplicationRecord
  belongs_to :user
  belongs_to :subscription_plan, optional: true

  validates :plan_name, presence: true
  validates :status, presence: true
  validates :stripe_id, uniqueness: true, allow_nil: true

  scope :active, -> { where(status: "active") }
  scope :pending, -> { where(status: "pending") }
  scope :cancelled, -> { where(status: "cancelled") }
  scope :current, -> { where("current_period_end > ?", Time.current) }

  # Pay integration methods
  def self.sync_from_pay_subscription(pay_subscription)
    subscription = find_or_initialize_by(stripe_id: pay_subscription.processor_id)

    subscription.update(
      user_id: pay_subscription.customer.owner_id,
      plan_name: pay_subscription.name || pay_subscription.processor_plan,
      status: pay_subscription.status,
      current_period_start: pay_subscription.current_period_start,
      current_period_end: pay_subscription.ends_at
    )

    subscription
  end

  # Legacy methods preserved for backward compatibility
  def active?
    status == "active" && (current_period_end.nil? || current_period_end > Time.current)
  end

  def pending?
    status == "pending"
  end

  def cancelled?
    status == "cancelled"
  end

  def expired?
    current_period_end && current_period_end < Time.current
  end

  # Updated to use Pay for cancellation
  def cancel!
    return if cancelled?

    if stripe_id.present?
      begin
        # Find the Pay subscription and cancel it
        pay_subscription = user.subscriptions.find_by(processor_id: stripe_id)

        if pay_subscription
          result = pay_subscription.cancel
          update(status: "cancelled", ends_at: pay_subscription.ends_at) if result
          result
        else
          # Legacy subscription without corresponding Pay record
          # Try direct Stripe cancellation as fallback
          Stripe.api_key = ENV.fetch("STRIPE_SECRET_KEY")
          stripe_subscription = Stripe::Subscription.retrieve(stripe_id)
          stripe_subscription.cancel

          update(status: "cancelled", ends_at: Time.zone.at(stripe_subscription.current_period_end))
          true
        end
      rescue => e
        errors.add(:base, "Error canceling subscription: #{e.message}")
        false
      end
    else
      # Handle non-stripe subscription cancelation
      update(status: "cancelled", current_period_end: Time.current)
      true
    end
  end

  # Sync all subscriptions from Pay
  def self.sync_all_from_pay
    Pay::Subscription.find_each do |pay_subscription|
      sync_from_pay_subscription(pay_subscription)
    end
  end
end
