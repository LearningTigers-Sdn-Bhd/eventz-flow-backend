class ExhibitorTeamMember < ApplicationRecord
  belongs_to :exhibitor_kit
  belongs_to :attendee, polymorphic: true, optional: true

  validates :full_name, presence: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :phone, presence: true

  after_commit :sync_attendee_record, on: %i[create update]
  before_destroy :destroy_attendee_record

  private

  def sync_attendee_record
    ExhibitorTeamMemberAttendeeSyncService.new(self).call
  end

  def destroy_attendee_record
    attendee&.destroy!
  end
end
