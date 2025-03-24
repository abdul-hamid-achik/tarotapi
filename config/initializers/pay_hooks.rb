# Subscribe to Pay gem webhook events
Rails.application.config.to_prepare do
  # Pay uses a webhook delegator pattern instead of direct callbacks
  Pay::Webhooks.delegator.subscribe "stripe.customer.subscription.created", ->(event) do
    subscription = event.data.object
    # Find our user from the subscription
    user = User.joins("INNER JOIN pay_customers ON pay_customers.owner_id = users.id")
                .where(pay_customers: { processor_id: subscription.customer })
                .first

    return unless user

    # Create or update our subscription record
    our_subscription = Subscription.find_or_create_by(stripe_id: subscription.id)
    our_subscription.update(
      user_id: user.id,
      plan_name: subscription.items.data[0]&.price&.nickname || "default",
      status: subscription.status,
      current_period_start: Time.at(subscription.current_period_start),
      current_period_end: Time.at(subscription.current_period_end)
    )

    # Update user quota
    SubscriptionEventHandler.update_user_quota(user, our_subscription) if defined?(SubscriptionEventHandler)
  end

  Pay::Webhooks.delegator.subscribe "stripe.customer.subscription.updated", ->(event) do
    subscription = event.data.object
    our_subscription = Subscription.find_by(stripe_id: subscription.id)

    return unless our_subscription

    our_subscription.update(
      plan_name: subscription.items.data[0]&.price&.nickname || our_subscription.plan_name,
      status: subscription.status,
      current_period_start: Time.at(subscription.current_period_start),
      current_period_end: Time.at(subscription.current_period_end)
    )

    # Update user quota
    SubscriptionEventHandler.update_user_quota(our_subscription.user, our_subscription) if defined?(SubscriptionEventHandler)
  end

  Pay::Webhooks.delegator.subscribe "stripe.customer.subscription.deleted", ->(event) do
    subscription = event.data.object
    our_subscription = Subscription.find_by(stripe_id: subscription.id)

    return unless our_subscription

    our_subscription.update(status: "cancelled")

    # Reset user to free tier
    SubscriptionEventHandler.update_user_quota(our_subscription.user, our_subscription) if defined?(SubscriptionEventHandler)
  end
end
