class CertificateTemplatePolicy < ApplicationPolicy
  # The certificate template is always authorized against its parent event,
  # so `record` may be either an Event (collection/preview/send actions) or a
  # CertificateTemplate instance.
  def show?
    admin_for_event?
  end

  def create?
    admin_for_event?
  end

  def update?
    admin_for_event?
  end

  def destroy?
    admin_for_event?
  end

  def send_batch?
    admin_for_event?
  end

  def preview?
    admin_for_event?
  end

  private

  def admin_for_event?
    return false if user.blank? || record.blank?

    event = record.is_a?(Event) ? record : record.event
    return false if event.blank?

    user.is_org_owner? || user.is_organizer? || user.is_event_admin?(event)
  end
end
