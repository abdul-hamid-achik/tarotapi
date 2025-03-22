class UsageLog < ApplicationRecord
  # Associations
  belongs_to :organization
  belongs_to :user, optional: true

  # Validations
  validates :organization_id, presence: true
  validates :metric_type, presence: true
  validates :recorded_at, presence: true
  validates :metadata, presence: true

  # Scopes
  scope :api_calls, -> { where(metric_type: "api_call") }
  scope :readings, -> { where(metric_type: :reading) }
  scope :active_sessions, -> { where(metric_type: :session).where("recorded_at > ?", 30.minutes.ago) }
  scope :by_date_range, ->(start_date, end_date) { where(recorded_at: start_date..end_date) }
  scope :by_metric_type, ->(type) { where(metric_type: type) }
  scope :successful, -> { where("metadata->>'status' LIKE '2%'") }
  scope :failed, -> { where("metadata->>'status' LIKE '5%'") }

  # Store metadata as jsonb
  store_accessor :metadata,
                :endpoint,
                :status,
                :response_time,
                :concurrent_count,
                :error_message

  # Class methods for analytics
  class << self
    def record_api_call!(organization:, user: nil, endpoint:, status:, response_time:)
      create!(
        organization: organization,
        user: user,
        metric_type: :api_call,
        recorded_at: Time.current,
        metadata: {
          endpoint: endpoint,
          status: status,
          response_time: response_time
        }
      )
    end

    def record_reading!(organization:, user:)
      create!(
        organization: organization,
        user: user,
        metric_type: :reading,
        recorded_at: Time.current
      )
    end

    def record_session!(organization:, user:)
      concurrent_count = active_sessions.where(organization_id: organization.id).count + 1

      create!(
        organization: organization,
        user: user,
        metric_type: :session,
        recorded_at: Time.current,
        metadata: {
          concurrent_count: concurrent_count
        }
      )
    end

    def record_error!(organization:, user: nil, error_message:, endpoint: nil)
      create!(
        organization: organization,
        user: user,
        metric_type: :error,
        recorded_at: Time.current,
        metadata: {
          error_message: error_message,
          endpoint: endpoint
        }
      )
    end

    def track!(organization, metric_type, user = nil, metadata = {})
      create!(
        organization: organization,
        user: user,
        metric_type: metric_type,
        metadata: metadata,
        recorded_at: Time.current
      )
    end

    def daily_metrics(start_date = nil, end_date = nil)
      start_date ||= 30.days.ago.beginning_of_day
      end_date ||= Time.current.end_of_day

      group("date_trunc('day', recorded_at)")
        .group(:metric_type)
        .count
    end

    def average_response_time(start_date = nil, end_date = nil)
      start_date ||= 30.days.ago.beginning_of_day
      end_date ||= Time.current.end_of_day

      where(recorded_at: start_date..end_date)
        .where(metric_type: "api_call")
        .average("(metadata->>'response_time')::float")
    end

    def error_rate(start_date = nil, end_date = nil)
      start_date ||= 30.days.ago.beginning_of_day
      end_date ||= Time.current.end_of_day

      total = where(recorded_at: start_date..end_date)
        .where(metric_type: "api_call")
        .count

      errors = where(recorded_at: start_date..end_date)
        .where(metric_type: "api_call")
        .where("metadata->>'status' LIKE '5%'")
        .count

      return 0 if total.zero?
      (errors.to_f / total * 100).round(2)
    end
  end

  # Instance methods
  def api_call?
    metric_type.to_sym == :api_call
  end

  def reading?
    metric_type.to_sym == :reading
  end

  def session?
    metric_type.to_sym == :session
  end

  def error?
    metric_type.to_sym == :error
  end

  def successful?
    metadata["status"].to_s.start_with?("2")
  end

  def failed?
    metadata["status"].to_s.start_with?("5")
  end

  def response_time
    metadata["response_time"].to_f
  end
end
