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

  def cancel!
    return if cancelled?

    if stripe_id.present?
      begin
        stripe_subscription = Stripe::Subscription.retrieve(stripe_id)
        stripe_subscription.cancel

        update(status: "cancelled", ends_at: Time.zone.at(stripe_subscription.current_period_end))
        true
      rescue Stripe::StripeError => e
        errors.add(:base, "Error canceling subscription: #{e.message}")
        false
      end
    else
      # Handle non-stripe subscription cancelation
      update(status: "cancelled", current_period_end: Time.current)
      true
    end
  end
end
