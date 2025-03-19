class Subscription < ApplicationRecord
  belongs_to :user

  validates :stripe_id, presence: true, uniqueness: true
  validates :plan_name, presence: true
  validates :status, presence: true

  def active?
    status == "active"
  end

  def canceled?
    status == "canceled"
  end

  def cancel!
    return if canceled?

    begin
      stripe_subscription = Stripe::Subscription.retrieve(stripe_id)
      stripe_subscription.cancel

      update(status: "canceled", ends_at: Time.zone.at(stripe_subscription.current_period_end))
      true
    rescue Stripe::StripeError => e
      errors.add(:base, "failed to cancel subscription: #{e.message}")
      false
    end
  end
end
