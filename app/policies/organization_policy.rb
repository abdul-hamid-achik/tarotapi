class OrganizationPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      # Users can see organizations they are members of
      scope.joins(:memberships).where(memberships: { user_id: user.id })
    end
  end

  def show?
    member?
  end

  def create?
    # Any authenticated user can create an organization
    user.present?
  end

  def update?
    admin?
  end

  def destroy?
    admin?
  end

  def manage_members?
    admin?
  end

  def view_usage?
    admin? || member?
  end

  def view_analytics?
    admin?
  end

  def manage_api_keys?
    admin?
  end

  private

  def member?
    return false unless user && record
    record.memberships.active.exists?(user: user)
  end

  def admin?
    return false unless user && record
    record.memberships.active.admins.exists?(user: user)
  end
end
