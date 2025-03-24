class SubscriptionEventHandler
  # Processes user quota updates based on subscription changes
  def self.update_user_quota(user, subscription)
    return unless user

    quota = user.reading_quota || user.build_reading_quota

    if subscription.active?
      plan = SubscriptionPlan.find_by(name: subscription.plan_name.downcase)

      if plan
        # Set limits based on plan
        default_limit = ENV.fetch("DEFAULT_FREE_TIER_LIMIT", 100).to_i
        default_llm_limit = ENV.fetch("DEFAULT_LLM_CALLS_LIMIT", 1000).to_i

        quota.monthly_limit = plan.reading_limit || default_limit
        quota.llm_calls_limit = plan.has_feature?("unlimited_llm") ? Float::INFINITY : default_llm_limit
        quota.reset_date = subscription.current_period_end || (Date.today.end_of_month + 1.day)
        quota.save!

        # Reset usage counters for upgrades
        if subscription.status == "active" && subscription.saved_change_to_plan_name?
          quota.update!(
            readings_this_month: 0,
            llm_calls_this_month: 0
          )
        end

        # Log the quota change
        Rails.logger.info "Updated quota for user #{user.id}: #{quota.monthly_limit} readings, #{quota.llm_calls_limit} LLM calls"
      end
    else
      # Reset to free tier limits for inactive subscriptions
      default_limit = ENV.fetch("DEFAULT_FREE_TIER_LIMIT", 100).to_i
      default_llm_limit = ENV.fetch("DEFAULT_LLM_CALLS_LIMIT", 1000).to_i

      quota.update!(
        monthly_limit: default_limit,
        llm_calls_limit: default_llm_limit,
        reset_date: Date.today.end_of_month + 1.day
      )
    end

    # Log the subscription event
    log_subscription_event(user, subscription)
  end

  def self.log_subscription_event(user, subscription)
    # Skip logging if the organization model is not available
    return unless defined?(Organization) && user.respond_to?(:organization)
    return unless user.organization.present?

    # Record the subscription event in usage logs if the organization exists
    UsageLog.track!(
      user.organization,
      "subscription_event",
      user,
      {
        plan: subscription.plan_name,
        status: subscription.status,
        event: subscription.saved_changes? ? "updated" : "created",
        period_start: subscription.current_period_start,
        period_end: subscription.current_period_end
      }
    )
  end
end
