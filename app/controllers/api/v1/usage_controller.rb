class Api::V1::UsageController < ApplicationController
  include AuthenticateRequest

  def index
    # Get subscription info
    subscription = current_user.subscriptions.active.first
    subscription_plan = subscription ? SubscriptionPlan.find_by(name: subscription.plan_name.downcase) : nil

    # Get organization
    organization = current_user.respond_to?(:organization) ? current_user.organization : nil

    # Prepare response
    response = {}

    # Include subscription information
    response[:subscription] = subscription ? {
      id: subscription.id,
      plan: subscription.plan_name,
      status: subscription.status,
      current_period_start: subscription.current_period_start,
      current_period_end: subscription.current_period_end,
      features: subscription_plan&.features_list || []
    } : nil

    # Include reading quota
    if current_user.respond_to?(:reading_quota) && current_user.reading_quota
      quota = current_user.reading_quota
      response[:reading_quota] = {
        monthly_limit: quota.monthly_limit,
        used_this_month: quota.readings_this_month,
        remaining: quota.remaining,
        reset_date: quota.reset_date,
        llm_calls_limit: quota.llm_calls_limit,
        llm_calls_used: quota.llm_calls_this_month,
        llm_calls_remaining: quota.llm_calls_remaining
      }
    end

    # Include API usage if organization is available
    if organization
      # Get period parameters
      days = params[:days].to_i
      days = 30 if days <= 0 || days > 90
      period_start = days.days.ago

      # Get API usage summary
      response[:api_usage] = ApiUsageService.usage_summary_for_user(current_user, period_start)

      # Add rate limit info
      response[:api_usage][:rate_limit] = {
        limit_per_minute: ApiUsageService.rate_limit_for_user(current_user)
      }
    end

    # Include user credits if available
    if defined?(UserCredit) && current_user.respond_to?(:user_credits)
      credit_balance = UserCredit.respond_to?(:balance_for) ?
                       UserCredit.balance_for(current_user) :
                       current_user.user_credits.sum(:amount)

      response[:credits] = {
        balance: credit_balance,
        recent_transactions: current_user.user_credits.order(created_at: :desc).limit(10).map { |c| {
          id: c.id,
          amount: c.amount,
          type: c.transaction_type,
          date: c.created_at,
          description: c.description,
          expires_at: c.expires_at
        }}
      }
    end

    render json: response
  end

  def daily
    # Get organization
    organization = current_user.respond_to?(:organization) ? current_user.organization : nil

    unless organization
      return render json: { error: "Organization not found" }, status: :not_found
    end

    # Get period parameters
    days = params[:days].to_i
    days = 30 if days <= 0 || days > 90
    period_start = days.days.ago.beginning_of_day
    period_end = Time.current

    # Get usage logs
    logs = UsageLog.where(
      organization_id: organization.id,
      recorded_at: period_start..period_end
    )

    # Group by day and metric type
    metrics = {}

    # Process the logs by day and type
    daily_data = logs.group("DATE(recorded_at)")
                    .group(:metric_type)
                    .count

    daily_data.each do |(date, type), count|
      date_str = date.to_s
      metrics[date_str] ||= {}
      metrics[date_str][type] = count
    end

    render json: {
      period: {
        start: period_start,
        end: period_end,
        days: days
      },
      metrics: metrics
    }
  end
end
