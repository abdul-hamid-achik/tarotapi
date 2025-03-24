class ApiUsageService
  def self.track_request(organization, user, endpoint, status_code, response_time, api_key_id = nil)
    # Record the API call in the usage logs
    UsageLog.record_api_call!(
      organization: organization,
      user: user,
      endpoint: endpoint,
      status: status_code.to_s,
      response_time: response_time
    )

    # If we have an API key, record its usage
    if api_key_id.present?
      api_key = ApiKey.find_by(id: api_key_id)
      api_key&.record_usage! if api_key&.respond_to?(:record_usage!)
    end
  end

  def self.usage_summary_for_user(user, period_start = nil, period_end = nil)
    # Find the organization for this user
    organization = user.respond_to?(:organization) ? user.organization : nil
    return {} unless organization

    period_start ||= current_period_start(user)
    period_end ||= Time.current

    # Get API calls for this user
    logs = UsageLog.where(
      organization_id: organization.id,
      user_id: user.id,
      recorded_at: period_start..period_end,
      metric_type: "api_call"
    )

    # Calculate summary statistics
    {
      total_requests: logs.count,
      successful_requests: logs.successful.count,
      failed_requests: logs.failed.count,
      average_response_time: logs.average("(metadata->>'response_time')::float"),
      endpoints: top_endpoints(logs),
      daily_usage: daily_usage(logs)
    }
  end

  def self.current_period_start(user)
    subscription = user.subscriptions.active.first
    if subscription&.current_period_start
      subscription.current_period_start
    else
      30.days.ago
    end
  end

  def self.rate_limit_for_user(user)
    # Get rate limit based on subscription level
    subscription = user.subscriptions.active.first
    if subscription
      plan = SubscriptionPlan.find_by(name: subscription.plan_name.downcase)
      case plan&.name
      when "basic"
        250  # 250 requests per minute
      when "premium"
        500  # 500 requests per minute
      when "professional"
        1000 # 1000 requests per minute
      else
        100  # Default free tier
      end
    else
      100 # Default free tier
    end
  end

  private

  def self.top_endpoints(logs, limit = 5)
    logs.group("metadata->>'endpoint'")
      .order(count_all: :desc)
      .limit(limit)
      .count
  end

  def self.daily_usage(logs)
    logs.group("date_trunc('day', recorded_at)")
      .order("date_trunc('day', recorded_at)")
      .count
      .transform_keys { |k| k.to_date.to_s }
  end
end
