class SubscriptionPolicy < ApplicationPolicy
  def index?
    # Users can view their own subscriptions
    true
  end

  def show?
    # Users can only view their own subscriptions
    record.user_id == user.id
  end

  def create?
    # Anyone can create a subscription if they're logged in
    # and don't already have an active one
    return false unless user
    !user.subscriptions.active.exists?
  end

  def cancel?
    # Users can only cancel their own subscriptions
    return false unless user
    record.user_id == user.id && record.active?
  end

  def update_payment_method?
    # Users can update payment methods on their own subscriptions
    return false unless user
    record.user_id == user.id
  end

  def change_plan?
    # Users can change plans on their own active subscriptions
    return false unless user
    record.user_id == user.id && record.active?
  end

  def reactivate?
    # Users can reactivate their own cancelled subscriptions
    # as long as they don't have another active one
    return false unless user
    record.user_id == user.id &&
      record.cancelled? &&
      !user.subscriptions.active.exists?
  end

  class Scope < Scope
    def resolve
      if user.agent?
        scope.all # Agents can see all subscriptions
      else
        scope.where(user_id: user.id) # Users can only see their own subscriptions
      end
    end
  end
end
