class ExhibitorKit < ApplicationRecord
  # custom_fields_data doubles as internal bookkeeping storage for a few flows
  # (dedup fingerprints, batch tracking, in-flight payment method choice) alongside
  # genuine admin/vendor-submitted custom form fields. Anything that treats
  # custom_fields_data as "the custom fields the admin/exhibitor filled in" — the
  # import template's column list, the import's write path — must exclude these keys.
  SYSTEM_CUSTOM_FIELD_KEYS = [
    PublicExhibitorBookingService::FINGERPRINT_KEY, # dedup fingerprint on public bookings
    EventVendorBatchService::FINGERPRINT_FIELD,      # dedup fingerprint on admin batch bookings
    EventVendorBatchService::BATCH_KEY_FIELD,        # admin batch grouping key
    ExhibitorKitImportService::FINGERPRINT_KEY,      # dedup fingerprint on Excel import bookings
    'booking_batch_id',                              # batch grouping id, written by both booking flows
    'payment_option',                                # in-flight payment method choice, cleared on settle
    'zone',                                           # booth zone snapshot at booking time, derived data
    'is_booth_manager'                                # internal team-member-role flag, not a form field
  ].freeze

  belongs_to :event_vendor, class_name: 'Exhibitor', inverse_of: :exhibitor_kits
  belongs_to :exhibitor_booth_price, optional: true
  belongs_to :exhibitor_package, optional: true
  has_many :exhibitor_kit_payments, dependent: :destroy
  has_one :exhibitor_registration_payment, dependent: :destroy
  has_many :exhibitor_team_member_payments, dependent: :destroy
  has_many :exhibitor_team_members, dependent: :destroy
  has_many :exhibitor_kit_items, dependent: :destroy
  has_many :exhibitor_kit_printings, dependent: :destroy
  has_many :exhibitor_booths, dependent: :nullify
  has_many :custom_requests, dependent: :destroy
  has_one :applied_voucher, class_name: 'ExhibitorVoucher', foreign_key: :redeemed_by_exhibitor_kit_id,
    inverse_of: :redeemed_by_exhibitor_kit
  has_one_attached :payment_proof, dependent: :purge_later
  has_one_attached :ic_copy, dependent: :purge_later
  has_one_attached :customs_declaration_form, dependent: :purge_later
  has_one_attached :customs_duty_estimate, dependent: :purge_later

  accepts_nested_attributes_for :exhibitor_team_members, allow_destroy: true
  accepts_nested_attributes_for :exhibitor_kit_items, allow_destroy: true
  accepts_nested_attributes_for :exhibitor_kit_printings, allow_destroy: true
  accepts_nested_attributes_for :custom_requests, allow_destroy: true

  delegate :event, to: :event_vendor

  validates :booth_type, presence: true
  enum :payment_status, { unpaid: 0, paid: 1, waived: 2, sponsored: 3, deposit: 4 }
  enum :booking_status, { active: 0, paid: 1, cancelled: 2, expired: 3 }, prefix: :booking
  scope :active_or_paid, -> { where(booking_status: %i[active paid]) }

  # Counts toward "paid" for reporting purposes: actually paid, or excused from payment
  # (waived/sponsored). Shared by analytics and export so both agree on what "settled" means.
  def settled?
    paid? || waived? || sponsored?
  end

  # Revenue this booking represents (booth price * quantity), falling back to whatever
  # was actually recorded as paid when no price snapshot exists (e.g. legacy bookings).
  def booking_value
    quantity = [booth_quantity.to_i, 1].max
    unit_price = price_snapshot.to_d
    return amount_paid.to_d if unit_price.zero? && amount_paid.present?

    unit_price * quantity
  end
  validates :public_id, uniqueness: true
  validates :idempotency_key, uniqueness: { scope: :event_vendor_id }, allow_nil: true

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
  after_save :sync_booth_status, if: :saved_change_to_booking_status?
  before_validation :set_public_id
  after_commit :send_registration_received_email, on: :create, if: :should_send_registration_received_email?
  after_commit :send_payment_confirmed_email, if: :should_send_payment_confirmed_email?
  after_commit :sync_registration_payment_status, if: :just_marked_paid?
  after_commit :revert_booking_status_when_unpaid, if: :just_marked_unpaid?
  after_commit :reconcile_team_member_tickets, if: :should_reconcile_team_member_tickets?

  def destroy_with_event_vendor_cleanup!
    vendor_assignment = event_vendor

    vendor_assignment.with_lock do
      destroy!
      vendor_assignment.reload
      vendor_assignment.destroy! if vendor_assignment.exhibitor_kits.none? && vendor_assignment.event_leads.none?
    end
  end

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

  def set_public_id
    self.public_id ||= SecureRandom.base58(22)
  end

  def should_send_registration_received_email?
    pic_email_address.present?
  end

  def should_send_payment_confirmed_email?
    pic_email_address.present? && saved_change_to_payment_status? && paid?
  end

  def just_marked_paid?
    saved_change_to_payment_status? && paid? && exhibitor_registration_payment.present? && exhibitor_registration_payment.status != 'paid'
  end

  def sync_registration_payment_status
    update!(booking_status: :paid, reservation_expires_at: nil) unless booking_paid?
    exhibitor_registration_payment.update!(status: 'paid', paid_at: Time.current, payment_method: 'manual_bank_transfer')
  end

  # Manually reverting payment_status (e.g. via admin "Manage Payment") only flips that column,
  # but booking_status was left stuck on 'paid' from the earlier sync above, which blocks
  # cancellation (Cancel Kit requires booking_status active). Revert it symmetrically.
  def just_marked_unpaid?
    saved_change_to_payment_status? && unpaid? && booking_paid?
  end

  def revert_booking_status_when_unpaid
    update!(booking_status: :active)
  end

  def remove_payment_option_when_payment_is_settled
    return if unpaid?
    return unless custom_fields_data.is_a?(Hash)
    return unless custom_fields_data.key?('payment_option') || custom_fields_data.key?(:payment_option)

    self.custom_fields_data = custom_fields_data.except('payment_option', :payment_option)
  end

  # Booking status is changed from several payment and admin paths. Syncing here rather than in
  # each caller means future paths are covered too. after_save, not after_commit, so a rollback
  # takes the booth change with it.
  def sync_booth_status
    case booking_status
    when 'paid'
      exhibitor_booths.update_all(status: ExhibitorBooth.statuses[:booked])
    when 'cancelled', 'expired'
      exhibitor_booths.update_all(status: ExhibitorBooth.statuses[:available], exhibitor_kit_id: nil)
    end
  end

  def send_registration_received_email
    EmailDelivery::AuditedDelivery.deliver_later(
      mailer_name: 'ExhibitorRegistrationMailer',
      mailer_action: 'registration_received_email',
      args: [self],
      related: self,
      dedupe: true
    )
  end

  def send_payment_confirmed_email
    EmailDelivery::AuditedDelivery.deliver_later(
      mailer_name: 'ExhibitorRegistrationMailer',
      mailer_action: 'payment_confirmed_email',
      args: [self],
      related: self,
      dedupe: true
    )
  end

  def should_reconcile_team_member_tickets?
    saved_change_to_payment_status? && event&.use_ticket?
  end

  def reconcile_team_member_tickets
    ExhibitorTeamMemberTicketReconciliationService.new(self).call
  end
end
