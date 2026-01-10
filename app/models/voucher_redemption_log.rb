# Audits every successful voucher redemption transaction.
class VoucherRedemptionLog < ApplicationRecord
  include TimeSeriesAnalytics

  # --- Enums ---
  # enum :redemption_status, { completed: 0, cancelled: 1 }

  # --- Associations ---
  belongs_to :voucher
  belongs_to :redeemer, polymorphic: true  # Uses redeemer_type (string) and redeemer_id
  belongs_to :redeemer_staff, class_name: 'User', foreign_key: 'redeemer_staff_id', optional: true

  # --- Validations ---
  validates :voucher, presence: true
  validates :redeemer, presence: true
  validates :redemption_timestamp, presence: true
  validates :redemption_status, presence: true
  validates :transaction_gross_amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :discount_applied_value, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :transaction_net_amount, presence: true, numericality: { greater_than_or_equal_to: 0 }

  # --- Scopes ---
  scope :for_event, ->(event) { joins(:voucher).where(vouchers: { event: event }) }
  scope :total_discount_value, -> { sum(:discount_applied_value) }
  scope :total_sales, -> { sum(:transaction_net_amount) }
  scope :latest_redemption_transactions, -> { includes(voucher: :vendor).order(redemption_timestamp: :desc).limit(10) }

  # -- Class Methods --
  def self.top_scanned_vouchers
    joins(voucher: :vendor)
      .select('vouchers.id as voucher_id, vouchers.title as voucher_title, vouchers.voucher_code, users.full_name as vendor_name, COUNT(*) as redemption_count')
      .group('vouchers.id, vouchers.title, vouchers.voucher_code, users.full_name')
      .order('redemption_count DESC')
      .limit(5)
      .map do |record|
        {
          voucher_id: record.voucher_id,
          voucher_title: record.voucher_title,
          voucher_code: record.voucher_code,
          vendor_name: record.vendor_name,
          redemption_count: record.redemption_count
        }
      end
  end

  # -- Instance Methods --
  def as_json(options = {})
    super(options).merge(
      voucher_title: voucher.title,
      voucher_code: voucher.voucher_code,
      vendor_name: voucher.vendor&.full_name || voucher.vendor&.email || "Unknown",
      redeemer_name: redeemer.try(:full_name) || redeemer.try(:email) || "Unknown",
      redeemer_type: redeemer_type
    )
  end
end
