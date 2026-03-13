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
    attendee&.destroy!
  end

  def store_exhibitor_kit_for_reconciliation
    @exhibitor_kit_for_reconciliation = exhibitor_kit
  end

  def reconcile_tickets_after_destroy
    return if @exhibitor_kit_for_reconciliation.blank?

    ExhibitorTeamMemberTicketReconciliationService.new(@exhibitor_kit_for_reconciliation).call
  end
end
