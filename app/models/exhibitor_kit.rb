class ExhibitorKit < ApplicationRecord
  belongs_to :event_vendor, class_name: 'Exhibitor', inverse_of: :exhibitor_kit
  belongs_to :exhibitor_booth_price, optional: true
  has_many :exhibitor_kit_payments, dependent: :destroy
  has_one :exhibitor_registration_payment, dependent: :destroy
  has_many :exhibitor_team_member_payments, dependent: :destroy
  has_many :exhibitor_team_members, dependent: :destroy
  has_many :exhibitor_kit_items, dependent: :destroy
  has_many :exhibitor_kit_printings, dependent: :destroy
  has_many :custom_requests, dependent: :destroy
  has_one_attached :payment_proof, dependent: :purge_later

  accepts_nested_attributes_for :exhibitor_team_members, allow_destroy: true
  accepts_nested_attributes_for :exhibitor_kit_items, allow_destroy: true
  accepts_nested_attributes_for :exhibitor_kit_printings, allow_destroy: true
  accepts_nested_attributes_for :custom_requests, allow_destroy: true

  delegate :event, to: :event_vendor

  validates :booth_type, presence: true
  enum :payment_status, { unpaid: 0, paid: 1, waived: 2, sponsored: 3 }

  # Booth/company info - optional but validated if provided
  validates :booth_number, presence: true, allow_blank: true
  validates :name_on_fascia, length: { maximum: 30 }, allow_blank: true
  validates :company_name, presence: true, allow_blank: true
  validates :company_address, presence: true, allow_blank: true

  # PIC info - required
  validates :pic_full_name, presence: true
  validates :pic_contact_number, presence: true
  validates :pic_email_address, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :amount_paid, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :booth_quantity, numericality: { only_integer: true, greater_than: 0 }

  before_save :remove_payment_option_when_payment_is_settled
  after_commit :send_registration_received_email, on: :create, if: :should_send_registration_received_email?
  after_commit :send_payment_confirmed_email, if: :should_send_payment_confirmed_email?

  # --- Team Member Limit Methods ---

  # Get the team member limit from the event's setting
  def team_member_limit
    event&.exhibitor_team_member_limit&.team_member_limit
  end

  # Get the extra fee per team member from the event's setting
  def extra_team_member_fee
    event&.exhibitor_team_member_limit&.extra_team_member_fee || 0
  end

  # Check if a limit is configured for this event
  def has_team_member_limit?
    team_member_limit.present? && team_member_limit > 0
  end

  # Count of team members for this exhibitor kit
  def team_member_count
    exhibitor_team_members.count
  end

  # Calculate total excess team members beyond the limit (regardless of payment status)
  # Returns 0 if no limit is set or if within limit
  def excess_team_member_count
    return 0 unless has_team_member_limit?

    [team_member_count - team_member_limit, 0].max
  end

  # Count of extra members already paid for (from verified payments)
  def paid_extra_member_count
    exhibitor_team_member_payments.verified.sum(:extra_member_count)
  end

  # Count of paid extra slots currently used by existing excess members.
  def used_paid_extra_member_count
    [excess_team_member_count, paid_extra_member_count].min
  end

  # Count of extra members with payments in progress (pending or submitted)
  def in_progress_extra_member_count
    exhibitor_team_member_payments.where(status: %i[pending submitted]).sum(:extra_member_count)
  end

  # Unpaid excess count (excludes members with verified or in-progress payments)
  def unpaid_excess_team_member_count
    [excess_team_member_count - paid_extra_member_count - in_progress_extra_member_count, 0].max
  end

  # Check if vendor has unpaid excess team members
  def has_unpaid_excess_team_members?
    unpaid_excess_team_member_count > 0
  end

  # Charges for unpaid excess team members
  def extra_team_member_charges
    unpaid_excess_team_member_count * extra_team_member_fee
  end

  private

  def should_send_registration_received_email?
    pic_email_address.present?
  end

  def should_send_payment_confirmed_email?
    pic_email_address.present? && saved_change_to_payment_status? && paid?
  end

  def remove_payment_option_when_payment_is_settled
    return if unpaid?
    return unless custom_fields_data.is_a?(Hash)
    return unless custom_fields_data.key?('payment_option') || custom_fields_data.key?(:payment_option)

    self.custom_fields_data = custom_fields_data.except('payment_option', :payment_option)
  end

  def send_registration_received_email
    ExhibitorRegistrationMailer.registration_received_email(self).deliver_later
  end

  def send_payment_confirmed_email
    ExhibitorRegistrationMailer.payment_confirmed_email(self).deliver_later
  end
end
