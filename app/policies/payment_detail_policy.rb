class PaymentDetailPolicy < ApplicationPolicy
  def show?
    own_record?
  end

  def create?
    can_manage_payment_details?
  end

  def update?
    own_record?
  end

  def destroy?
    own_record?
  end

  private

  def own_record?
    record.user_id == user.id
  end

  def can_manage_payment_details?
    user.is_org_owner_or_organizer? || user.is_exhibition_contractor?
  end
end
