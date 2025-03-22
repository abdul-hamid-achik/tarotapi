class Organization < ApplicationRecord
  # Associations
  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :api_keys, dependent: :destroy
  has_many :usage_logs, dependent: :destroy

  # Validations
  validates :name, presence: true
  validates :plan, presence: true, inclusion: { in: %w[free basic pro enterprise] }
  validates :billing_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :status, presence: true, inclusion: { in: %w[active suspended cancelled] }

  # Scopes
  scope :active, -> { where(status: 'active') }
  scope :by_plan, ->(plan) { where(plan: plan) }

  # Features and quotas are stored as jsonb
  store_accessor :features, :max_members, :api_rate_limit, :custom_spreads, :white_label, :priority_support
  store_accessor :quotas, :daily_readings, :monthly_api_calls, :concurrent_sessions

  # Callbacks
  before_create :set_default_features_and_quotas
  
  # Instance methods
  def active?
    status == 'active'
  end

  def suspended?
    status == 'suspended'
  end

  def cancelled?
    status == 'cancelled'
  end

  def usage_metrics(start_date: nil, end_date: nil, granularity: :daily)
    start_date ||= 30.days.ago.beginning_of_day
    end_date ||= Time.current.end_of_day

    metrics = usage_logs
      .where(recorded_at: start_date..end_date)
      .group("date_trunc('#{granularity}', recorded_at)")
      .group(:metric_type)
      .count

    # Transform into a more usable format
    metrics.transform_keys do |key|
      date, type = key
      { date: date, type: type }
    end
  end

  def analytics(start_date: nil, end_date: nil, metrics: nil)
    start_date ||= 30.days.ago.beginning_of_day
    end_date ||= Time.current.end_of_day
    metrics ||= %w[api_calls unique_users response_time error_rate]

    # Collect analytics data based on requested metrics
    analytics_data = {}

    metrics.each do |metric|
      data = case metric
      when 'api_calls'
        api_call_analytics(start_date, end_date)
      when 'unique_users'
        unique_user_analytics(start_date, end_date)
      when 'response_time'
        response_time_analytics(start_date, end_date)
      when 'error_rate'
        error_rate_analytics(start_date, end_date)
      end

      analytics_data[metric] = data if data
    end

    analytics_data
  end

  private

  def set_default_features_and_quotas
    self.features ||= {}
    self.quotas ||= {}
    
    case plan
    when 'free'
      set_free_limits
    when 'basic'
      set_basic_limits
    when 'pro'
      set_pro_limits
    when 'enterprise'
      set_enterprise_limits
    end
  end

  def set_free_limits
    self.features.merge!(
      max_members: 5,
      api_rate_limit: 100,
      custom_spreads: false,
      white_label: false,
      priority_support: false
    )
    self.quotas.merge!(
      daily_readings: 100,
      monthly_api_calls: 10_000,
      concurrent_sessions: 10
    )
  end

  def set_basic_limits
    self.features.merge!(
      max_members: 20,
      api_rate_limit: 1000,
      custom_spreads: true,
      white_label: true,
      priority_support: false
    )
    self.quotas.merge!(
      daily_readings: 1000,
      monthly_api_calls: 100_000,
      concurrent_sessions: 50
    )
  end

  def set_pro_limits
    self.features.merge!(
      max_members: 100,
      api_rate_limit: 10000,
      custom_spreads: true,
      white_label: true,
      priority_support: true
    )
    self.quotas.merge!(
      daily_readings: 10000,
      monthly_api_calls: 1_000_000,
      concurrent_sessions: 250
    )
  end

  def set_enterprise_limits
    self.features.merge!(
      max_members: 100,
      api_rate_limit: 10000,
      custom_spreads: true,
      white_label: true,
      priority_support: true
    )
    self.quotas.merge!(
      daily_readings: 10000,
      monthly_api_calls: 1_000_000,
      concurrent_sessions: 250
    )
  end

  def api_call_analytics(start_date, end_date)
    usage_logs
      .where(recorded_at: start_date..end_date)
      .where(metric_type: 'api_call')
      .group("date_trunc('day', recorded_at)")
      .count
  end

  def unique_user_analytics(start_date, end_date)
    usage_logs
      .where(recorded_at: start_date..end_date)
      .where(metric_type: 'api_call')
      .group("date_trunc('day', recorded_at)")
      .distinct
      .count(:user_id)
  end

  def response_time_analytics(start_date, end_date)
    usage_logs
      .where(recorded_at: start_date..end_date)
      .where(metric_type: 'api_call')
      .group("date_trunc('day', recorded_at)")
      .average("(metadata->>'response_time')::float")
  end

  def error_rate_analytics(start_date, end_date)
    total_calls = usage_logs
      .where(recorded_at: start_date..end_date)
      .where(metric_type: 'api_call')
      .group("date_trunc('day', recorded_at)")
      .count

    error_calls = usage_logs
      .where(recorded_at: start_date..end_date)
      .where(metric_type: 'api_call')
      .where("metadata->>'status' LIKE '5%'")
      .group("date_trunc('day', recorded_at)")
      .count

    total_calls.transform_values.with_index do |total, date|
      errors = error_calls[date] || 0
      (errors.to_f / total * 100).round(2)
    end
  end
end 