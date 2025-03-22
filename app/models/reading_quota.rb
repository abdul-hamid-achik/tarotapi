class ReadingQuota < ApplicationRecord
  belongs_to :user

  validates :monthly_limit, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :readings_this_month, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :reset_date, presence: true
  validates :llm_calls_this_month, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :llm_calls_limit, presence: true, numericality: { greater_than_or_equal_to: 0 }

  def remaining
    monthly_limit - readings_this_month
  end

  def llm_calls_remaining
    llm_calls_limit - llm_calls_this_month
  end

  def increment_usage!
    return if user.subscription_status == "active"

    self.readings_this_month += 1
    save!
  end

  def increment_llm_call!(multiplier = 1)
    return if user.subscription_status == "active" && unlimited_llm_tier?

    self.llm_calls_this_month += multiplier
    self.last_llm_call_at = Time.current
    save!
  end

  def exceeded?
    remaining <= 0
  end

  def llm_calls_exceeded?
    return false if unlimited_llm_tier?
    llm_calls_remaining <= 0
  end

  def almost_exceeded?
    remaining.between?(1, 5)
  end

  def llm_calls_almost_exceeded?
    return false if unlimited_llm_tier?
    llm_calls_remaining.between?(1, 20)
  end

  def should_reset?
    reset_date <= Time.current
  end

  def reset!
    update!(
      readings_this_month: 0,
      llm_calls_this_month: 0,
      reset_date: Date.today.end_of_month + 1.day
    )
  end

  def reset_llm_calls!
    update!(llm_calls_this_month: 0)
  end

  private

  def unlimited_llm_tier?
    user.subscription_plan&.name == "unlimited" ||
    (user.subscription_status == "active" && user.subscription_plan&.features&.include?("unlimited_llm"))
  end
end
