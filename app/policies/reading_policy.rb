class ReadingPolicy < ApplicationPolicy
  def index?
    # Everyone can list their own readings
    true
  end

  def show?
    # Users can only view their own readings
    record.user_id == user.id
  end

  def create?
    return false unless user
    return true if user.agent? # Agents can always create readings
    
    # Check reading limits based on subscription
    return false unless user_within_reading_limit?
    
    # Free users can only create basic readings
    if !user_has_active_subscription?
      return record.spread.is_basic?
    end
    
    true
  end

  def update?
    # Users can only update their own readings
    record.user_id == user.id
  end

  def destroy?
    # Users can only delete their own readings
    record.user_id == user.id
  end

  def stream?
    # Streaming is a premium feature
    return false unless show?
    user_has_premium_subscription? || user_has_professional_subscription?
  end

  def export_pdf?
    # PDF export is a premium feature
    return false unless show?
    user_has_premium_subscription? || user_has_professional_subscription?
  end

  def advanced_interpretation?
    # Advanced interpretation is a professional feature
    return false unless show?
    user_has_professional_subscription?
  end

  class Scope < Scope
    def resolve
      if user.agent?
        scope.all # Agents can see all readings
      else
        scope.where(user_id: user.id) # Users can only see their own readings
      end
    end
  end
end 