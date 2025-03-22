class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index?
    false
  end

  def show?
    false
  end

  def create?
    false
  end

  def new?
    create?
  end

  def update?
    false
  end

  def edit?
    update?
  end

  def destroy?
    false
  end

  protected

  def user_has_active_subscription?
    user&.subscriptions&.find_by(status: "active").present?
  end

  def user_has_premium_subscription?
    subscription = user&.subscriptions&.find_by(status: "active")
    subscription&.plan_name&.downcase == "premium"
  end

  def user_has_professional_subscription?
    subscription = user&.subscriptions&.find_by(status: "active")
    subscription&.plan_name&.downcase == "professional"
  end

  def user_within_reading_limit?
    !user&.reading_limit_exceeded?
  end

  def user_can_access_feature?(feature)
    subscription = user&.subscriptions&.find_by(status: "active")
    return false unless subscription
    
    subscription_plan = subscription.subscription_plan
    return false unless subscription_plan
    
    subscription_plan.has_feature?(feature)
  end

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      raise NotImplementedError, "You must define #resolve in #{self.class}"
    end

    private

    attr_reader :user, :scope
  end
end 