class HealthPolicy < ApplicationPolicy
  def admin?
    # Check if user is an admin or has admin privileges
    # You can customize this based on your authorization setup
    return false unless user

    # For API keys, check if the associated user has admin privileges
    if defined?(@current_api_key) && @current_api_key.present?
      return @current_api_key.admin_access?
    end

    # Check for admin role
    return true if user.respond_to?(:admin?) && user.admin?

    # Check for organization admin status
    return true if user.respond_to?(:memberships) &&
                  user.memberships.exists?(role: "admin", status: "active")

    # Check for professional subscription (highest tier)
    user_has_professional_subscription?
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
