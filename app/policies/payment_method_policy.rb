class PaymentMethodPolicy < ApplicationPolicy
  def detach?
    # Users can only detach their own payment methods
    return false unless user
    record.customer.owner_id == user.id
  end

  def make_default?
    # Users can only set their own payment methods as default
    return false unless user
    record.customer.owner_id == user.id
  end

  class Scope < Scope
    def resolve
      if user.agent?
        scope.all # Agents can see all payment methods
      else
        scope.joins(:customer).where(pay_customers: { owner_id: user.id }) # Users can only see their own payment methods
      end
    end
  end
end
