class Api::V1::SubscriptionsController < ApplicationController
  include AuthenticateRequest

  def create
    # Initialize Stripe with API key
    Stripe.api_key = ENV["STRIPE_SECRET_KEY"]

    # Find or create Stripe customer
    customer = find_or_create_stripe_customer

    # Create the subscription
    begin
      subscription = Stripe::Subscription.create({
        customer: customer.id,
        items: [ { price: params[:price_id] } ],
        expand: [ "latest_invoice.payment_intent" ]
      })

      # Store subscription in our database
      @subscription = current_user.subscriptions.create(
        stripe_id: subscription.id,
        stripe_customer_id: customer.id,
        plan_name: params[:plan_name],
        status: subscription.status,
        current_period_start: Time.zone.at(subscription.current_period_start),
        current_period_end: Time.zone.at(subscription.current_period_end)
      )

      render json: {
        subscription_id: @subscription.id,
        status: @subscription.status,
        client_secret: subscription.latest_invoice.payment_intent.client_secret
      }, status: :created
    rescue Stripe::StripeError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end

  def show
    @subscription = current_user.subscriptions.find_by(id: params[:id])

    if @subscription
      render json: {
        id: @subscription.id,
        plan_name: @subscription.plan_name,
        status: @subscription.status,
        current_period_end: @subscription.current_period_end
      }
    else
      render json: { error: "subscription not found" }, status: :not_found
    end
  end

  def cancel
    @subscription = current_user.subscriptions.find_by(id: params[:id])

    if @subscription&.cancel!
      render json: {
        id: @subscription.id,
        status: @subscription.status,
        ends_at: @subscription.ends_at
      }
    else
      render json: { error: "failed to cancel subscription" }, status: :unprocessable_entity
    end
  end

  private

  def find_or_create_stripe_customer
    if current_user.stripe_customer_id.present?
      Stripe::Customer.retrieve(current_user.stripe_customer_id)
    else
      customer = Stripe::Customer.create({
        email: current_user.email,
        name: current_user.email.split("@").first # Use email username as name
      })

      current_user.update(stripe_customer_id: customer.id)
      customer
    end
  end
end
