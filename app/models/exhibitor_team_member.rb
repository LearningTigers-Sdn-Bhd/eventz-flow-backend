class ExhibitorTeamMember < ApplicationRecord
  belongs_to :exhibitor_kit
  belongs_to :attendee, polymorphic: true, optional: true

  validates :full_name, presence: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :phone, presence: true

  after_commit :sync_attendee_record, on: %i[create update]
  after_commit :reconcile_tickets_after_commit, on: %i[create update]
  before_destroy :destroy_attendee_record
  before_destroy :store_exhibitor_kit_for_reconciliation
  after_commit :reconcile_tickets_after_destroy, on: :destroy

  private

  def sync_attendee_record
    ExhibitorTeamMemberAttendeeSyncService.new(self).call
  end

  def reconcile_tickets_after_commit
    ExhibitorTeamMemberTicketReconciliationService.new(exhibitor_kit).call
  end

  def destroy_attendee_record
    return attendee&.destroy! unless attendee.is_a?(Ticket)
    return unless attendee.ticket_type&.name == ExhibitorTeamMemberAttendeeSyncService::EXHIBITOR_TICKET_TYPE_NAME
    return if ExhibitorTeamMemberTicketReconciliationService.shared?(self, excluding: self)

    attendee.destroy!
  end

  def store_exhibitor_kit_for_reconciliation
    @exhibitor_kit_for_reconciliation = exhibitor_kit
  end

  def reconcile_tickets_after_destroy
    return if @exhibitor_kit_for_reconciliation.blank?

    @exhibitor_kit_for_reconciliation.event_vendor.exhibitor_kits.each do |kit|
      ExhibitorTeamMemberTicketReconciliationService.new(kit).call
    end
  end
end
