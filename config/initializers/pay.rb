Pay.setup do |config|
  # For use in receipt/invoice emails
  config.application_name = "Tarot API"
  config.business_name = "Tarot API, Inc."
  config.business_address = "1234 Main St, Suite 100, City, State 10001"
  config.support_email = ENV.fetch("SUPPORT_EMAIL", "support@tarotapi.cards")

  config.default_product_name = "Tarot Reading Subscription"
  config.default_plan_name = "Basic"

  # Set business logo
  # config.business_logo = "logo.png"

  # Stripe
  config.enabled_processors = [:stripe]
end 

# Configure Stripe webhooks
Rails.application.config.to_prepare do
  Pay::Webhooks.delegator.subscribe "stripe.charge.succeeded", Pay::Stripe::Webhooks::ChargeSucceeded.new
  Pay::Webhooks.delegator.subscribe "stripe.charge.refunded", Pay::Stripe::Webhooks::ChargeRefunded.new
  Pay::Webhooks.delegator.subscribe "stripe.payment_intent.succeeded", Pay::Stripe::Webhooks::PaymentIntentSucceeded.new
  Pay::Webhooks.delegator.subscribe "stripe.payment_method.attached", Pay::Stripe::Webhooks::PaymentMethodAttached.new
  Pay::Webhooks.delegator.subscribe "stripe.customer.updated", Pay::Stripe::Webhooks::CustomerUpdated.new
  Pay::Webhooks.delegator.subscribe "stripe.customer.deleted", Pay::Stripe::Webhooks::CustomerDeleted.new
  Pay::Webhooks.delegator.subscribe "stripe.subscription.created", Pay::Stripe::Webhooks::SubscriptionCreated.new
  Pay::Webhooks.delegator.subscribe "stripe.subscription.updated", Pay::Stripe::Webhooks::SubscriptionUpdated.new
  Pay::Webhooks.delegator.subscribe "stripe.subscription.deleted", Pay::Stripe::Webhooks::SubscriptionDeleted.new
end 