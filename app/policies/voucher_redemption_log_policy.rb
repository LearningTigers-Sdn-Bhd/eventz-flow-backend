class VoucherRedemptionLogPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      if user&.is_vendor?
        scope.joins(:voucher).where(vouchers: { vendor_id: user.id })
      elsif user&.is_org_owner? || user&.is_organizer?
        scope.all
      else
        scope.none
      end
    end
  end

  def index?
    user&.is_org_owner? || user&.is_organizer? || user&.is_vendor?
  end

  # For event-specific authorization (handles event_admin check)
  def view_redemption_logs?
    return true if user&.is_org_owner? || user&.is_organizer?
    return true if user&.is_vendor?
    return true if record.is_a?(Event) && user&.is_event_admin?(record)

    false
  end
end
