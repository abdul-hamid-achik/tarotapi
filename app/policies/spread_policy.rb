class SpreadPolicy < ApplicationPolicy
  def index?
    # Everyone can list public spreads
    true
  end

  def show?
    # Anyone can view public spreads
    return true if record.is_public? || record.is_system?

    # Users can view their own spreads
    record.user_id == user&.id
  end

  def create?
    return false unless user
    return true if user.agent? # Agents can always create spreads

    # Custom spread creation is a premium feature
    user_has_premium_subscription? || user_has_professional_subscription?
  end

  def update?
    return false unless user
    return true if user.agent?

    # Users can only update their own spreads
    record.user_id == user.id
  end

  def destroy?
    return false unless user
    return true if user.agent?

    # Users can only delete their own spreads
    # System spreads cannot be deleted
    record.user_id == user.id && !record.is_system?
  end

  def publish?
    return false unless user
    return true if user.agent?

    # Publishing spreads requires a professional subscription
    return false unless user_has_professional_subscription?

    # Can only publish own spreads
    record.user_id == user.id
  end

  class Scope < Scope
    def resolve
      # Start with public and system spreads
      base = scope.where(is_public: true).or(scope.where(is_system: true))

      if user
        # Add user's own spreads if logged in
        base.or(scope.where(user_id: user.id))
      else
        base
      end
    end
  end
end
