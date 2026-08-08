# frozen_string_literal: true

class BusinessMatchingSessionPolicy < ApplicationPolicy
  # Event staff (org owner/organizer/event admin/team member) can update any
  # session; the host assigned to this specific session can update their own.
  def update?
    return false if user.blank? || record.blank?
    return true if EventPolicy.new(user, record.event).manage_business_matching_sessions?

    assigned_host?
  end

  # Only event staff may create/delete sessions — hosts never manage the
  # session roster itself.
  def create?
    return false if user.blank? || record.blank?
    EventPolicy.new(user, record.event).manage_business_matching_sessions?
  end

  def destroy?
    create?
  end

  private

  def assigned_host?
    host_id = record.business_host_assignments.pick(:user_id)
    host_id.present? && host_id == user.id
  end
end
