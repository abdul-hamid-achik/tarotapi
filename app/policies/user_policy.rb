class UserPolicy < ApplicationPolicy
  def manage_payment_methods?
    # Users can manage their own payment methods
    return false unless user
    record.id == user.id
  end

  def update_profile?
    # Users can update their own profile
    return false unless user
    record.id == user.id
  end

  def create_agent?
    # Only users with professional subscriptions can create agent users
    return false unless user
    user_has_professional_subscription?
  end

  def view_analytics?
    # Only users with premium or professional subscriptions can view analytics
    return false unless user
    user_has_premium_subscription? || user_has_professional_subscription?
  end

  class Scope < Scope
    def resolve
      if user.agent?
        scope.all # Agents can see all users
      else
        scope.where(id: user.id) # Users can only see themselves
      end
    end
  end
end
